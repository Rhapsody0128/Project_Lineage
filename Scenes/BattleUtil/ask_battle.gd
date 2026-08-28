extends CanvasLayer

# =========================================================
# 全域共用的「是否跳過戰鬥」詢問彈窗(以 autoload 掛載於 project.godot,
# 任何場景呼叫 AskBattle.ask(...) 即可彈出;外殼比照 CharacterPanel 的
# 彈出式對話框寫法——背景遮罩 + 面板 + 按鈕)。
#
# 兩個選項都是「self_party 對上呼叫端指定的 enemy_party」開戰,差別只在:
# 選「是」(跳過)→ 直接把整場戰鬥模擬完寫入戰報(不進 Battle 場景播放),接著彈出
# 「是否觀看戰報？」提示問玩家要不要順便看這場戰鬥的詳細數字(見 _show_report_prompt()),
# 不管選哪邊,最後都會接續原本該做的事(呼叫端的 on_result 或切去 skip_return_scene_path);
# 選「否」→ 走即時戰鬥(BattleReportStore.pending_self_party/pending_enemy_party
# 交接模式,REALTIME 模式開放回合間手動施放奧義),切去呼叫端傳入的 battle_scene_path。
# =========================================================

const BATTLE_REPORT_STATS_SCENE_PATH := "res://Scenes/BattleReportStats/battle_report_stats.tscn"

const WIN_COLOR := Color(0.15, 0.5, 0.15)
const LOSE_COLOR := Color(0.9, 0.1, 0.1)
const DRAW_COLOR := Color(0.0, 0.0, 0.0)

@onready var root: Control = $Root
@onready var panel_box: PanelContainer = $Root/CenterContainer/PanelBox
@onready var skip_button: Button = $Root/CenterContainer/PanelBox/Content/ButtonRow/SkipButton
@onready var fight_button: Button = $Root/CenterContainer/PanelBox/Content/ButtonRow/FightButton
@onready var report_prompt_box: PanelContainer = $Root/CenterContainer/ReportPromptBox
@onready var report_result_label: Label = $Root/CenterContainer/ReportPromptBox/Content/ResultLabel
@onready var view_report_button: Button = $Root/CenterContainer/ReportPromptBox/Content/ButtonRow/ViewReportButton
@onready var skip_report_button: Button = $Root/CenterContainer/ReportPromptBox/Content/ButtonRow/SkipReportButton

var _self_party: Party
var _enemy_party: Party
var _battle_scene_path: String
var _skip_return_scene_path: String
var _report_title: String
var _on_result: Callable
## 選填加碼:呼叫端想拿到這場戰鬥完整的 BattleReport(不只是勝負結果)就傳一個簽章
## func(report: BattleReport) 的 Callable——兩條路徑(跳過/親臨戰場)都會呼叫到,見
## _on_skip_button_pressed()/_on_fight_button_pressed()。例如 WarBattleEvent 連續作戰
## 要把每一場的報表收進 WarCampaignReport.fight_reports。
var _on_report: Callable
## 這場戰鬥要不要一併寫進戰報列表的「一般戰鬥」清單(BattleReportStore.reports)——預設
## true(維持原本行為)。WarBattleEvent 連續作戰傳 false:每一場戰報已經靠 on_report
## 收進 WarCampaignReport.fight_reports、掛在戰報列表的「戰爭戰報」分類底下,不該同時
## 也出現在「一般戰鬥」清單重複一份。
var _record_in_report_list: bool = true
## 這場戰鬥的 BattleReport.description(留空時用預設的「O級敵人遭遇戰」,見
## BattleReport._default_description())——WarCampaignReport 連續作戰要指定成
## 「豹 VS 鷹 戰場戰報-1」這種格式,見 WarBattleEvent._ask_next_campaign_battle()。
var _report_description: String
## 打贏要不要順帶呼叫 BattleReward.grant_victory_favor()。預設 true(維持原本行為:
## 遊蕩者/攻城戰的 enemy_party.nation_type 代表「失地待救的國家」,打贏加好感度合理)。
## WarBattleEvent 連續作戰傳 false——那裡的 nation_type 是正在打的敵對國,打贏不該替
## 敵對國加好感度,好感度改由戰功在停戰時一次結算,見 ask() 同名參數註解。
var _grant_nation_favor: bool = true
## 選「是，跳過」直接模擬完戰鬥後,存著這份戰報給「是否觀看戰報？」提示用,
## 見 _show_report_prompt()/_on_view_report_button_pressed()。
var _pending_report: BattleReport


func _ready() -> void:
	for button in [skip_button, fight_button, view_report_button, skip_report_button]:
		UiStyle.apply_wood_plaque_button(button, 16.0, 8.0)
		button.add_theme_font_size_override("font_size", 18)

	UiStyle.apply_parchment_panel(panel_box, 420.0, 180.0)
	UiStyle.apply_parchment_panel(report_prompt_box, 420.0, 180.0)

	root.visible = false
	report_prompt_box.visible = false


## 呼叫端(例如城門守衛「闖進去」)問玩家是否跳過戰鬥,雙方固定用 self_party
## 對上 enemy_party(呼叫端指定,不是隨機生的敵方隊伍)。report_title 留空時
## 用目前世界時間字串,跟其他戰報標題一致(見 BattleReportStore._seed_demo_reports())。
## on_result 是選填的加碼:呼叫端想在戰鬥結束時依勝負做點什麼(例如城門守衛依勝負
## 秀不同台詞),就傳一個簽章 func(result: GameEnums.BattleResultType) 的 Callable——
## 傳了就由它決定戰鬥結束後要去哪個場景,不再直接切去 skip_return_scene_path/
## Battle 場景的預設返回行為(見 _on_skip_button_pressed()/Scenes/Battle/battle.gd 的
## _on_back_pressed())。留空(預設)就是原本「打完直接回上一頁」的行為。on_report 是
## 另一個選填加碼,簽章 func(report: BattleReport)——呼叫端想拿到這場戰鬥完整的戰報
## (不只是勝負結果,例如 WarBattleEvent 連續作戰要收進 WarCampaignReport.fight_reports)
## 才需要傳,兩條路徑(跳過/親臨戰場)都會呼叫到,見 _on_report 欄位註解。
## record_in_report_list/report_description 見同名欄位註解,預設值維持原本行為(寫進
## 一般戰鬥清單、描述用預設的「O級敵人遭遇戰」)。grant_nation_favor 見同名欄位註解,
## 預設 true。
func ask(
	self_party: Party, enemy_party: Party, battle_scene_path: String, skip_return_scene_path: String,
	report_title: String = "", on_result: Callable = Callable(), on_report: Callable = Callable(),
	record_in_report_list: bool = true, report_description: String = "", grant_nation_favor: bool = true
) -> void:
	_self_party = self_party
	_enemy_party = enemy_party
	_battle_scene_path = battle_scene_path
	_skip_return_scene_path = skip_return_scene_path
	_report_title = report_title
	_on_result = on_result
	_on_report = on_report
	_record_in_report_list = record_in_report_list
	_report_description = report_description
	_grant_nation_favor = grant_nation_favor
	panel_box.visible = true
	report_prompt_box.visible = false
	root.visible = true


## 選「是」:不進 Battle 場景,直接模擬完整場戰鬥、寫入戰報列表,再問玩家要不要
## 順便看一下戰報(原本打完直接無聲切場景,玩家完全看不到這場戰鬥打得如何)。
func _on_skip_button_pressed() -> void:
	panel_box.visible = false
	var title := _report_title if not _report_title.is_empty() else WorldTimeStore.get_display_string()
	var report := BattleController.generate_report_for_parties(
		title, _self_party, _enemy_party, _report_description, _grant_nation_favor
	)
	if _record_in_report_list:
		BattleReportStore.add_report(report)
	if _on_report.is_valid():
		_on_report.call(report)
	_show_report_prompt(report)


## 彈「是否觀看戰報？」提示,順便秀一下這場戰鬥的勝負,取代原本的 PanelBox
## (root 本身維持顯示,只切裡面顯示的面板)。
func _show_report_prompt(report: BattleReport) -> void:
	_pending_report = report
	report_result_label.text = report.result_text
	report_result_label.add_theme_color_override("font_color", _result_color(report.result))
	report_prompt_box.visible = true


func _result_color(result: GameEnums.BattleResultType) -> Color:
	match result:
		GameEnums.BattleResultType.SELF_WIN:
			return WIN_COLOR
		GameEnums.BattleResultType.ENEMY_WIN:
			return LOSE_COLOR
		_:
			return DRAW_COLOR


## 選「觀看戰報」:切去 BattleReportStats 看這場戰鬥的詳細數字(跟戰報列表「戰報」
## 按鈕同一套交接模式,見 BattleReportStore.queue_stats());原本打完該做的事(呼叫
## on_result 或切去 skip_return_scene_path)存進 pending_stats_continuation,等玩家在
## BattleReportStats 按「返回」時才真正接續執行。
func _on_view_report_button_pressed() -> void:
	root.visible = false
	report_prompt_box.visible = false
	var report := _pending_report
	BattleReportStore.queue_stats(report)
	BattleReportStore.pending_stats_continuation = func() -> void: _continue_after_skip_battle(report.result)
	var error := get_tree().change_scene_to_file(BATTLE_REPORT_STATS_SCENE_PATH)
	if error != OK:
		printerr("Error changing scene from AskBattle view report: ", error)


## 選「略過」:不看戰報,直接照原本「打完直接回上一頁」的行為接續下去。
func _on_skip_report_button_pressed() -> void:
	root.visible = false
	report_prompt_box.visible = false
	_continue_after_skip_battle(_pending_report.result)


func _continue_after_skip_battle(result: GameEnums.BattleResultType) -> void:
	if _on_result.is_valid():
		_on_result.call(result)
		return
	var error := get_tree().change_scene_to_file(_skip_return_scene_path)
	if error != OK:
		printerr("Error changing scene from AskBattle skip: ", error)


## 選「否」:交給 Battle 場景走即時戰鬥(可手動施放奧義)。_on_result 一併存進
## BattleReportStore.pending_battle_result_callback,等玩家在 Battle 場景打完按「返回」
## 時才會真正呼叫到(見該檔案註解)。
func _on_fight_button_pressed() -> void:
	root.visible = false
	BattleReportStore.pending_self_party = _self_party
	BattleReportStore.pending_enemy_party = _enemy_party
	BattleReportStore.pending_battle_mode = GameEnums.BattleMode.REALTIME
	BattleReportStore.pending_battle_result_callback = _on_result
	BattleReportStore.pending_battle_report_callback = _on_report
	BattleReportStore.pending_battle_record_in_report_list = _record_in_report_list
	BattleReportStore.pending_battle_report_description = _report_description
	BattleReportStore.pending_battle_grant_nation_favor = _grant_nation_favor
	var error := get_tree().change_scene_to_file(_battle_scene_path)
	if error != OK:
		printerr("Error changing scene from AskBattle fight: ", error)
