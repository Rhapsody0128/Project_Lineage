extends CanvasLayer

# =========================================================
# 全域共用的「是否跳過戰鬥」詢問彈窗(以 autoload 掛載於 project.godot,
# 任何場景呼叫 AskBattle.ask(...) 即可彈出;外殼比照 CharacterPanel 的
# 彈出式對話框寫法——背景遮罩 + 面板 + 按鈕)。
#
# 兩個選項都是「self_party 對上呼叫端指定的 enemy_party」開戰,差別只在:
# 選「是」(跳過)→ 直接把整場戰鬥模擬完寫入戰報(不進 Battle 場景播放),
# 接著切去呼叫端傳入的 skip_return_scene_path;
# 選「否」→ 走即時戰鬥(BattleReportStore.pending_self_party/pending_enemy_party
# 交接模式,REALTIME 模式開放回合間手動施放奧義),切去呼叫端傳入的 battle_scene_path。
# =========================================================

@onready var root: Control = $Root
@onready var skip_button: Button = $Root/CenterContainer/PanelBox/Margin/Content/ButtonRow/SkipButton
@onready var fight_button: Button = $Root/CenterContainer/PanelBox/Margin/Content/ButtonRow/FightButton

var _self_party: Party
var _enemy_party: Party
var _battle_scene_path: String
var _skip_return_scene_path: String
var _report_title: String
var _on_result: Callable


func _ready() -> void:
	root.visible = false


## 呼叫端(例如城堡守衛「闖進去」)問玩家是否跳過戰鬥,雙方固定用 self_party
## 對上 enemy_party(呼叫端指定,不是隨機生的敵方隊伍)。report_title 留空時
## 用目前世界時間字串,跟其他戰報標題一致(見 BattleReportStore._seed_demo_reports())。
## on_result 是選填的加碼:呼叫端想在戰鬥結束時依勝負做點什麼(例如城堡守衛依勝負
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
	root.visible = true


## 選「是」:不進 Battle 場景,直接模擬完整場戰鬥、寫入戰報列表。
func _on_skip_button_pressed() -> void:
	root.visible = false
	var title := _report_title if not _report_title.is_empty() else MapSessionStore.current_world_time_string()
	var report := BattleController.generate_report_for_parties(title, _self_party, _enemy_party)
	BattleReportStore.add_report(report)
	if _on_result.is_valid():
		_on_result.call(report.result)
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
