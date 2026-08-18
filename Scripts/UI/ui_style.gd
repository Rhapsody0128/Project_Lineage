class_name UiStyle
extends RefCounted

## 共用的 StyleBoxFlat 邊框樣式建構器,取代 battle_party_roster.gd/battle_report_list.gd/
## character_panel.gd 四處各自手刻同一種「背景色 + 四邊等寬邊框 + 四角同半徑圓角」樣式碼。
## 回傳的 StyleBoxFlat 仍是一般可變物件,呼叫端要動態改邊框顏色(例如放技能時頭像框
## 高亮)一樣直接改回傳值的 border_color,不影響這裡。

static func bordered_panel(
	bg: Color,
	border_color: Color,
	border_width: int = 2,
	corner_radius: int = 0,
	content_margin_h: float = 0.0,
	content_margin_v: float = 0.0
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner_radius)
	style.content_margin_left = content_margin_h
	style.content_margin_right = content_margin_h
	style.content_margin_top = content_margin_v
	style.content_margin_bottom = content_margin_v
	return style


const WOOD_BUTTON_NORMAL_TEXTURE := preload("res://Images/UI/wood_button_normal.png")
const WOOD_BUTTON_HOVER_TEXTURE := preload("res://Images/UI/wood_button_hover.png")
const WOOD_BUTTON_PRESSED_TEXTURE := preload("res://Images/UI/wood_button_pressed.png")
const WOOD_BUTTON_DISABLED_TEXTURE := preload("res://Images/UI/wood_button_disabled.png")

## 木牌鐵框按鈕樣式(見 main.tscn 的 Start/Quit),共用同一組 PNG 素材與雕刻字體配色,
## 呼叫端(場景腳本)在 `_ready()` 對每顆 Button 呼叫一次即可,不用在 .tscn 裡把
## StyleBoxTexture/字體 theme_override 各複製一份。
static func apply_wood_plaque_button(
	button: Button,
	content_margin_h: float = 60.0,
	content_margin_v: float = 50.0
) -> void:
	button.add_theme_stylebox_override("normal", _wood_button_stylebox(WOOD_BUTTON_NORMAL_TEXTURE, content_margin_h, content_margin_v))
	button.add_theme_stylebox_override("hover", _wood_button_stylebox(WOOD_BUTTON_HOVER_TEXTURE, content_margin_h, content_margin_v))
	button.add_theme_stylebox_override("pressed", _wood_button_stylebox(WOOD_BUTTON_PRESSED_TEXTURE, content_margin_h, content_margin_v))
	button.add_theme_stylebox_override("focus", _wood_button_stylebox(WOOD_BUTTON_HOVER_TEXTURE, content_margin_h, content_margin_v))
	button.add_theme_stylebox_override("disabled", _wood_button_stylebox(WOOD_BUTTON_DISABLED_TEXTURE, content_margin_h, content_margin_v))

	button.add_theme_color_override("font_color", Color(0.88, 0.82, 0.68, 1))
	button.add_theme_color_override("font_hover_color", Color(1, 0.92, 0.68, 1))
	button.add_theme_color_override("font_pressed_color", Color(0.72, 0.65, 0.52, 1))
	button.add_theme_color_override("font_outline_color", Color(0.18, 0.1, 0.055, 0.9))
	button.add_theme_color_override("font_disabled_color", Color(0.55, 0.5, 0.44, 0.8))
	button.add_theme_constant_override("outline_size", 3)
	button.add_theme_font_size_override("font_size", 28)


static func _wood_button_stylebox(texture: Texture2D, content_margin_h: float, content_margin_v: float) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.content_margin_left = content_margin_h
	style.content_margin_right = content_margin_h
	style.content_margin_top = content_margin_v
	style.content_margin_bottom = content_margin_v
	return style
