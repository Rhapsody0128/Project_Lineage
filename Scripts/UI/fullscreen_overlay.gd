class_name FullscreenOverlay
extends CanvasLayer

# =========================================================
# 通用「蓋滿整個畫面」彈出面板殼——取代告白/求婚等情境原本借用
# Scenes/ActionPanel/action_panel.gd(ActionPanel.open_custom())的做法。跟 ActionPanel
# 不同的是這裡不是 autoload 單例,每次呼叫端要用就 FullscreenOverlay.new() 一份塞進場景樹
# (get_tree().root.add_child()),疊在目前畫面最上層——不管底下是 Dialogue 還是另一層
# ActionPanel(例如根據地建築面板),都留在原地繼續顯示、不受影響、不會被取代/釋放,
# close() 時只有這層自己 queue_free()。不切場景。
#
# 內容(content)完全由呼叫端組好塞入 open(),外殼只負責背景遮罩、標題列、× 關閉鈕跟
# 版面(近全螢幕,四邊留 SCREEN_MARGIN)。on_close_button 選填:按下 × 時要執行的動作——
# 呼叫端通常會讓它轉呼叫內容自己的 decline()/cancel() 方法,由那個方法自己決定何時真的
# 呼叫 close()(例如先回報結果給呼叫端),外殼不假設「按 × 一定等於立刻關閉」,不像
# ActionPanel.close() 那樣內建 trigger_callback 旗標;不需要特別處理時留空,× 直接
# close() 掉自己。
#
# 見 Scenes/CharacterSelect/character_select_overlay.gd 的 CharacterSelectOverlay——選人
# 情境用的是那個更專用的外殼(內建 CharacterSelectPanel 版面),尺寸跟這裡共用同一個
# SCREEN_MARGIN,長相統一。
# =========================================================

const LAYER := 30
const SCREEN_MARGIN := 40.0

var content_slot: MarginContainer

var _title_label: Label
var _close_button: Button


func _init() -> void:
	layer = LAYER


func _ready() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var box := PanelContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = SCREEN_MARGIN
	box.offset_top = SCREEN_MARGIN
	box.offset_right = -SCREEN_MARGIN
	box.offset_bottom = -SCREEN_MARGIN
	var viewport_size := get_viewport().get_visible_rect().size
	UiStyle.apply_parchment_panel(box, viewport_size.x - SCREEN_MARGIN * 2, viewport_size.y - SCREEN_MARGIN * 2, 24.0, 24.0, 24.0, 24.0)
	dim.add_child(box)

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

	_close_button = Button.new()
	_close_button.text = "×"
	UiStyle.apply_wood_plaque_button(_close_button, 10.0, 4.0)
	_close_button.add_theme_font_size_override("font_size", 18)
	top_bar.add_child(_close_button)

	content_slot = MarginContainer.new()
	content_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(content_slot)


## title/content 由呼叫端決定;content 直接塞進 content_slot(自己負責裡面所有互動/按鈕)。
## on_close_button 不傳時 × 直接 close() 掉自己。
func open(title: String, content: Control, on_close_button: Callable = Callable()) -> void:
	_title_label.text = title
	content_slot.add_child(content)
	_close_button.pressed.connect(on_close_button if on_close_button.is_valid() else close)


func close() -> void:
	queue_free()
