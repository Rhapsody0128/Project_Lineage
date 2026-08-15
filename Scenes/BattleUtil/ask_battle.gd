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


func _ready() -> void:
	root.visible = false


## 呼叫端(例如城堡守衛「闖進去」)問玩家是否跳過戰鬥,雙方固定用 self_party
## 對上 enemy_party(呼叫端指定,不是隨機生的敵方隊伍)。report_title 留空時
## 用目前世界時間字串,跟其他戰報標題一致(見 BattleReportStore._seed_demo_reports())。
func ask(self_party: Party, enemy_party: Party, battle_scene_path: String, skip_return_scene_path: String, report_title: String = "") -> void:
	_self_party = self_party
	_enemy_party = enemy_party
	_battle_scene_path = battle_scene_path
	_skip_return_scene_path = skip_return_scene_path
	_report_title = report_title
	root.visible = true


## 選「是」:不進 Battle 場景,直接模擬完整場戰鬥、寫入戰報列表。
func _on_skip_button_pressed() -> void:
	root.visible = false
	var title := _report_title if not _report_title.is_empty() else MapSessionStore.current_world_time_string()
	var report := BattleController.generate_report_for_parties(title, _self_party, _enemy_party)
	BattleReportStore.add_report(report)
	var error := get_tree().change_scene_to_file(_skip_return_scene_path)
	if error != OK:
		printerr("Error changing scene from AskBattle skip: ", error)


## 選「否」:交給 Battle 場景走即時戰鬥(可手動施放奧義)。
func _on_fight_button_pressed() -> void:
	root.visible = false
	BattleReportStore.pending_self_party = _self_party
	BattleReportStore.pending_enemy_party = _enemy_party
	BattleReportStore.pending_battle_mode = GameEnums.BattleMode.REALTIME
	var error := get_tree().change_scene_to_file(_battle_scene_path)
	if error != OK:
		printerr("Error changing scene from AskBattle fight: ", error)
