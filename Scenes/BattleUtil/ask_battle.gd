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

const WIN_COLOR := Color(0.55, 0.85, 0.55)
const LOSE_COLOR := Color(0.9, 0.5, 0.5)
const DRAW_COLOR := Color(0.85, 0.8, 0.6)

@onready var root: Control = $Root
@onready var panel_box: PanelContainer = $Root/CenterContainer/PanelBox
@onready var skip_button: Button = $Root/CenterContainer/PanelBox/Margin/Content/ButtonRow/SkipButton
@onready var fight_button: Button = $Root/CenterContainer/PanelBox/Margin/Content/ButtonRow/FightButton
@onready var report_prompt_box: PanelContainer = $Root/CenterContainer/ReportPromptBox
@onready var report_result_label: Label = $Root/CenterContainer/ReportPromptBox/Margin/Content/ResultLabel
@onready var view_report_button: Button = $Root/CenterContainer/ReportPromptBox/Margin/Content/ButtonRow/ViewReportButton
@onready var skip_report_button: Button = $Root/CenterContainer/ReportPromptBox/Margin/Content/ButtonRow/SkipReportButton

var _self_party: Party
var _enemy_party: Party
var _battle_scene_path: String
var _skip_return_scene_path: String
var _report_title: String
var _on_result: Callable
## 選「是，跳過」直接模擬完戰鬥後,存著這份戰報給「是否觀看戰報？」提示用,
## 見 _show_report_prompt()/_on_view_report_button_pressed()。
var _pending_report: BattleReport


func _ready() -> void:
	root.visible = false
	report_prompt_box.visible = false


## 呼叫端(例如城門守衛「闖進去」)問玩家是否跳過戰鬥,雙方固定用 self_party
## 對上 enemy_party(呼叫端指定,不是隨機生的敵方隊伍)。report_title 留空時
## 用目前世界時間字串,跟其他戰報標題一致(見 BattleReportStore._seed_demo_reports())。
## on_result 是選填的加碼:呼叫端想在戰鬥結束時依勝負做點什麼(例如城門守衛依勝負
## 秀不同台詞),就傳一個簽章 func(result: GameEnums.BattleResultType) 的 Callable——
## 傳了就由它決定戰鬥結束後要去哪個場景,不再直接切去 skip_return_scene_path/
## Battle 場景的預設返回行為(見 _on_skip_button_pressed()/Scenes/Battle/battle.gd 的
## _on_back_pressed())。留空(預設)就是原本「打完直接回上一頁」的行為。
func ask(self_party: Party, enemy_party: Party, battle_scene_path: String, skip_return_scene_path: String, report_title: String = "", on_result: Callable = Callable()) -> void:
	_self_party = self_party
	_enemy_party = enemy_party
	_battle_scene_path = battle_scene_path
	_skip_return_scene_path = skip_return_scene_path
	_report_title = report_title
	_on_result = on_result
	panel_box.visible = true
	report_prompt_box.visible = false
	root.visible = true


## 選「是」:不進 Battle 場景,直接模擬完整場戰鬥、寫入戰報列表,再問玩家要不要
## 順便看一下戰報(原本打完直接無聲切場景,玩家完全看不到這場戰鬥打得如何)。
func _on_skip_button_pressed() -> void:
	panel_box.visible = false
	var title := _report_title if not _report_title.is_empty() else WorldTimeStore.get_display_string()
	var report := BattleController.generate_report_for_parties(title, _self_party, _enemy_party)
	BattleReportStore.add_report(report)
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
	var error := get_tree().change_scene_to_file(_battle_scene_path)
	if error != OK:
		printerr("Error changing scene from AskBattle fight: ", error)
