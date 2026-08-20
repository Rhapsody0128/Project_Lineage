extends CanvasLayer

# =========================================================
# 全域共用的通用「是/否」確認彈窗(autoload,見 project.godot)。外殼比照
# Scenes/BattleUtil/ask_battle.gd 的彈出式對話框寫法(背景遮罩 + PanelBox + 按鈕),
# 差別是這裡不綁定戰鬥流程——任何場景/事件只要有「是否要做某件事」的提示需求,
# 呼叫 ConfirmDialog.ask(message, on_yes, on_no) 就能彈出,不用再各自開一顆
# CanvasLayer 彈窗。目前唯一的呼叫端是 System/event/town/town_tavern_event.gd
# 角色列已滿時問玩家要不要去角色列表解雇一位角色騰位置。
#
# CanvasLayer.layer=15,介於 ActionPanel/AskBattle(10)跟 CharacterPanel(20)之間——
# 這顆彈窗常常疊在 ActionPanel 之上彈出(例如酒館招募清單開著時跳出來問),
# 所以要蓋過 10,但不需要蓋過全域最上層的 CharacterPanel。
# =========================================================

@onready var root: Control = $Root
@onready var panel_box: PanelContainer = $Root/CenterContainer/PanelBox
@onready var question_label: Label = $Root/CenterContainer/PanelBox/Margin/Content/QuestionLabel
@onready var yes_button: Button = $Root/CenterContainer/PanelBox/Margin/Content/ButtonRow/YesButton
@onready var no_button: Button = $Root/CenterContainer/PanelBox/Margin/Content/ButtonRow/NoButton

var _on_yes: Callable
var _on_no: Callable


func _ready() -> void:
	for button in [yes_button, no_button]:
		UiStyle.apply_wood_plaque_button(button, 16.0, 8.0)
		button.add_theme_font_size_override("font_size", 18)
	# 跟 ask_battle.tscn 的 PanelBox 同一組尺寸/留白慣例,見該檔案註解。
	UiStyle.apply_parchment_panel(panel_box, 420.0, 180.0, 160.0, 120.0, 160.0, 120.0)
	root.visible = false


## 任何場景/事件都可呼叫:ConfirmDialog.ask(message, on_yes, on_no)。on_no 選填
## ——「否」不需要額外接續動作(單純關掉彈窗)時可以留空。yes_label/no_label 選填,
## 預設「是」/「否」。
func ask(message: String, on_yes: Callable, on_no: Callable = Callable(), yes_label: String = "是", no_label: String = "否") -> void:
	question_label.text = message
	yes_button.text = yes_label
	no_button.text = no_label
	_on_yes = on_yes
	_on_no = on_no
	root.visible = true


func _on_yes_button_pressed() -> void:
	var callback := _on_yes
	_reset()
	if callback.is_valid():
		callback.call()


func _on_no_button_pressed() -> void:
	var callback := _on_no
	_reset()
	if callback.is_valid():
		callback.call()


func _reset() -> void:
	root.visible = false
	_on_yes = Callable()
	_on_no = Callable()
