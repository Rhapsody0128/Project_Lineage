class_name BattleUltimatePanel
extends PanelContainer

# =========================================================
# 即時戰鬥模式(Scenes/Battle/battle.gd 的 _run_battle_realtime())專用:board 下方的
# 奧義施放面板。純粹畫面表現+輸入轉發——按下奧義按鈕只發出 ultimate_selected 訊號,
# 實際能不能放/放了會發生什麼事一律交給 System 層(Battle.cast_ultimate()),這裡不
# 判斷、不寫規則,呼應 CLAUDE.md「System 管邏輯,Scenes 管畫面」。
#
# 不會逐回合暫停詢問——面板從戰鬥開始就一直開著,戰鬥照樣自動連續播放,玩家隨時想放
# 就直接按(還放得出來的話),按下去只是把這次施放排進佇列,下一回合開始才生效
# (見 Ultimate.delay_rounds/Battle.cast_ultimate()),不影響戰鬥本身的播放節奏。
# =========================================================

signal ultimate_selected(ultimate: Ultimate)

@onready var hint_label: Label = $HBox/HintLabel
@onready var button_row: HBoxContainer = $HBox/ButtonRow

var _buttons: Dictionary = {} # Ultimate -> Button


## 依可施放的奧義清單建立按鈕,只在戰鬥一開始呼叫一次(清單本身不會在戰鬥中變動,
## 變的只是「還能不能放」,見 refresh_button())。面板固定貼在畫面最下緣一條窄帶
## (見 battle.tscn 的 UltimatePanel offset,不管戰報面板展開/收合都在戰場之外,
## 不會被 LogToggleButton 收合戰報時撐大的戰場蓋到),按鈕尺寸配合這條窄帶縮小。
func setup(ultimates: Array[Ultimate]) -> void:
	for child in button_row.get_children():
		child.queue_free()
	_buttons.clear()

	for ultimate in ultimates:
		var button := Button.new()
		button.custom_minimum_size = Vector2(150, 24)
		button.add_theme_font_size_override("font_size", 13)
		button.text = ultimate.name
		button.tooltip_text = ultimate.description
		button.pressed.connect(_on_ultimate_button_pressed.bind(ultimate))
		button_row.add_child(button)
		_buttons[ultimate] = button


## 依目前是否還放得出來(Battle.can_cast_ultimate())+ 還剩幾次(Battle.
## ultimate_uses_remaining(),-1 代表不限次數)更新單一按鈕的可按狀態與文字。
func refresh_button(ultimate: Ultimate, can_cast: bool, uses_remaining: int) -> void:
	var button: Button = _buttons.get(ultimate)
	if button == null:
		return
	button.disabled = not can_cast
	var count_text := "∞" if uses_remaining < 0 else str(uses_remaining)
	button.text = "%s (%s)" % [ultimate.name, count_text]


func open_cast_window() -> void:
	visible = true


func close_cast_window() -> void:
	visible = false


func _on_ultimate_button_pressed(ultimate: Ultimate) -> void:
	ultimate_selected.emit(ultimate)
