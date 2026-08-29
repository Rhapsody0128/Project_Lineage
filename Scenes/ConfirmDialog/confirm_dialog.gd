extends CanvasLayer

# =========================================================
# 全域共用的通用「是/否」確認彈窗(autoload,見 project.godot)。外殼比照
# Scenes/BattleUtil/ask_battle.gd 的彈出式對話框寫法(背景遮罩 + PanelBox + 按鈕),
# 差別是這裡不綁定戰鬥流程——任何場景/事件只要有「是否要做某件事」的提示需求,
# 呼叫 ConfirmDialog.ask(message, on_yes, on_no) 就能彈出,不用再各自開一顆
# CanvasLayer 彈窗。目前唯一的呼叫端是 System/event/town/town_tavern_event.gd
# 角色列已滿時問玩家要不要去角色列表解雇一位角色騰位置。
#
# CanvasLayer.layer=35,蓋過 ActionPanel/AskBattle(10)、CharacterPanel(20)、
# Scenes/CharacterSelect/character_select_overlay.gd 的 CharacterSelectOverlay(30)——
# 這是全域最後一道「你確定嗎」提示,不管玩家當下疊了幾層彈窗(例如根據地指派工作角色的
# CharacterSelectOverlay 開著時跳出來問是否把某人從別的建築改調過來,見
# Scenes/Base/worker_dispatch_panel.gd),都要蓋在最上面才點得到,所以固定取全專案最高。
#
# notify(message, on_ack) 是同一個外殼的單按鈕變體——把 NoButton 藏起來、YesButton 文字
# 改「確定」,純粹「提示一下、按確定才繼續」的情境用這個,不要為了單一按鈕另外疊一個
# MessageBar toast(那個是不擋輸入的角落訊息,跟這裡「小框+確定鈕」的彈窗語氣不一樣)。
# 見 Scenes/Map/world_inner.gd 遷移根據地選點流程的提示/錯誤/結果訊息。
# =========================================================

@onready var root: Control = $Root
@onready var panel_box: PanelContainer = $Root/CenterContainer/PanelBox
@onready var question_label: Label = $Root/CenterContainer/PanelBox/Content/QuestionLabel
@onready var yes_button: Button = $Root/CenterContainer/PanelBox/Content/ButtonRow/YesButton
@onready var no_button: Button = $Root/CenterContainer/PanelBox/Content/ButtonRow/NoButton

var _on_yes: Callable
var _on_no: Callable


func _ready() -> void:
	for button in [yes_button, no_button]:
		UiStyle.apply_wood_plaque_button(button, 16.0, 8.0)
		button.add_theme_font_size_override("font_size", 18)
	UiStyle.apply_parchment_panel(panel_box, 420.0, 180.0)
	root.visible = false


## 任何場景/事件都可呼叫:ConfirmDialog.ask(message, on_yes, on_no)。on_no 選填
## ——「否」不需要額外接續動作(單純關掉彈窗)時可以留空。yes_label/no_label 選填,
## 預設「是」/「否」。
func ask(message: String, on_yes: Callable, on_no: Callable = Callable(), yes_label: String = "是", no_label: String = "否") -> void:
	question_label.text = message
	yes_button.text = yes_label
	no_button.text = no_label
	no_button.visible = true
	_on_yes = on_yes
	_on_no = on_no
	root.visible = true


## 單按鈕變體:只提示訊息、按「確定」才繼續,沒有「否」的分支(見上方開頭註解)。
## on_ack 選填——純粹告知玩家一件事、不需要接續動作時可以留空。
func notify(message: String, on_ack: Callable = Callable()) -> void:
	question_label.text = message
	yes_button.text = "確定"
	no_button.visible = false
	_on_yes = on_ack
	_on_no = Callable()
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
