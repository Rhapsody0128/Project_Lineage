class_name CharacterSelectOverlay
extends CanvasLayer

# =========================================================
# 疊加在目前畫面最上層的獨立選人彈窗——外殼比照 Scenes/ActionPanel/action_panel.gd 既有的
# 彈出視覺語言(半透明黑幕 + CenterContainer 置中 + 固定大小 PanelBox),不是近全螢幕:
# 選人畫面(CharacterSelectPanel)本身不需要蓋滿整個螢幕,固定大小的置中彈窗版面更單純。
# 不借用 ActionPanel 本身——這裡經常需要疊加在「目前已經開著的 ActionPanel 內容之上」而
# 不取代它,所以自成一層獨立 CanvasLayer(layer 設得比它高,見 LAYER),疊上來的當下底下
# 的 ActionPanel(根據地建築面板)完全不受影響,繼續留在畫面上(半透明黑幕之後)、也不會
# 被釋放——挑一位角色只是
# 「疊一層視窗蓋在上面」,不是「把底下的面板整包替換/釋放掉再重建」。呼叫端
# (見 Scenes/Base/base_action_panel.gd 的 _open_dispatch_picker() 等)因此可以直接沿用
# self 讀寫狀態、呼叫 _rebuild_body(),不必顧慮 self 生命週期。
#
# 不是 autoload 單例(不像 ActionPanel/CharacterPanel 那樣全域只有一份、需要跨呼叫端共用
# 狀態)——每次呼叫端要選人就 CharacterSelectOverlay.new() 一份全新的塞進場景樹,close()
# 時自己 queue_free(),沒有殘留狀態的疑慮。
# =========================================================

## ActionPanel(Scenes/ActionPanel/action_panel.tscn)是 layer 10、CharacterPanel
## (Scenes/CharacterPanel/character_panel.tscn)是 layer 20——這裡要疊在兩者最上面,
## 所以取更高的 30。
const LAYER := 30

var panel: CharacterSelectPanel

var _title_label: Label


func _init() -> void:
	layer = LAYER


func _ready() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.add_child(center)

	# 用 ActionPanel 既有的 DEFAULT_MIN_SIZE 當固定彈窗尺寸,不再依 viewport 現場算近全螢幕
	# 大小——選人畫面內容量比 ActionPanel 的清單少,沿用同一組「預設彈窗大小」慣例即可,
	# 不需要另外調一組數字。
	# apply_parchment_panel() 的 stylebox 本身就帶內距,跟 ActionPanel 的 PanelBox 一樣不用
	# 額外參數、全部吃預設值——不要另外疊一層 MarginContainer,單一內距來源,才不會跟
	# ActionPanel 內容的距離兜不起來。
	var box := PanelContainer.new()
	box.custom_minimum_size = ActionPanel.DEFAULT_MIN_SIZE
	UiStyle.apply_parchment_panel(box, ActionPanel.DEFAULT_MIN_SIZE.x, ActionPanel.DEFAULT_MIN_SIZE.y)
	center.add_child(box)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	box.add_child(content)

	var top_bar := HBoxContainer.new()
	content.add_child(top_bar)

	_title_label = Label.new()
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	top_bar.add_child(_title_label)

	var close_button := Button.new()
	close_button.text = "×"
	UiStyle.apply_wood_plaque_button(close_button, 10.0, 4.0)
	close_button.add_theme_font_size_override("font_size", 18)
	close_button.pressed.connect(close)
	top_bar.add_child(close_button)

	panel = CharacterSelectPanel.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(panel)
	panel.cancelled.connect(close)


## title/characters/card_factory/initial_sort_key/on_confirmed/confirm_label/initial_focus
## 直接轉呼叫 CharacterSelectPanel.setup()。確認選擇時先 close() 掉自己再呼叫
## on_confirmed——呼叫端接下來通常會呼叫 self._rebuild_body() 更新底下的建築面板,疊加
## 面板要先讓開,不要讓兩層同時疊在畫面上。initial_focus 選填:一開始就聚焦顯示某人,
## 不用玩家先點一次才看得到資料、按得下確認鈕(見 base_action_panel.gd 的
## _open_proposer_picker() 預設聚焦第一位未婚角色)。
func open_picker(title: String, characters: Array[Character], card_factory: Callable, initial_sort_key: int, on_confirmed: Callable, confirm_label: String = CharacterSelectPanel.DEFAULT_CONFIRM_LABEL, initial_focus: Character = null) -> void:
	_title_label.text = title
	panel.character_confirmed.connect(func(character: Character) -> void:
		close()
		on_confirmed.call(character)
	)
	panel.setup(characters, card_factory, initial_sort_key, false, initial_focus, confirm_label)


func close() -> void:
	queue_free()
