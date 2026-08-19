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
	content_margin_v: float = 0.0,
	shadow_size: int = 0,
	shadow_color: Color = Color(0, 0, 0, 0)
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
	if shadow_size > 0:
		style.shadow_size = shadow_size
		style.shadow_color = shadow_color
	return style


## 共用 ScrollContainer 捲軸樣式:預設 Godot 捲軸是深色系統風格,跟羊皮紙/木框面板
## (見 action_panel.tscn 的 panel_1980x1080.png)的暖色調不搭。呼叫端在 _ready() 對面板
## 內的 ScrollContainer 呼叫一次即可套用做舊木紋配色的捲軸——軌道用半透明羊皮紙色,
## 握把用木紋深棕色,圓角柔化邊緣,不是系統預設那種生硬的直角灰條。
static func apply_parchment_scrollbar(scroll_container: ScrollContainer) -> void:
	var v_scroll := scroll_container.get_v_scroll_bar()
	v_scroll.add_theme_stylebox_override("scroll", bordered_panel(
		Color(0.55, 0.42, 0.26, 0.16), Color(0.35, 0.22, 0.1, 0.3), 1, 6
	))
	v_scroll.add_theme_stylebox_override("grabber", bordered_panel(
		Color(0.42, 0.28, 0.14, 0.85), Color(0.24, 0.14, 0.06, 0.9), 1, 6
	))
	v_scroll.add_theme_stylebox_override("grabber_highlight", bordered_panel(
		Color(0.52, 0.36, 0.18, 0.95), Color(0.28, 0.16, 0.08, 1), 1, 6
	))
	v_scroll.add_theme_stylebox_override("grabber_pressed", bordered_panel(
		Color(0.32, 0.21, 0.1, 1), Color(0.2, 0.12, 0.05, 1), 1, 6
	))


## 羊皮紙面板底圖(Images/UI/Panel/)依實際比例分好幾種尺寸,不是單一張圖硬拉伸——
## 硬拉伸會讓四邊手繪的破損毛邊被橫向/縱向擠壓變形。每個呼叫端在 apply_parchment_panel()
## 傳入面板的設計寬高,_panel_texture_for_size() 依寬高比挑最接近的一張,不用呼叫端自己
## 對照檔名。新增素材時只要把新的 preload 加進 _PANEL_TEXTURE_RATIOS 陣列即可,不用改
## 呼叫端。
const _TEX_320x1080 := preload("res://Images/UI/Panel/panel_320x1080.png")
const _TEX_400x1080 := preload("res://Images/UI/Panel/panel_400x1080.png")
const _TEX_600x1080 := preload("res://Images/UI/Panel/panel_600x1080.png")
const _TEX_800x1080 := preload("res://Images/UI/Panel/panel_800x1080.png")
const _TEX_1080x1080 := preload("res://Images/UI/Panel/panel_1080x1080.png")
const _TEX_1200x1080 := preload("res://Images/UI/Panel/panel_1200x1080.png")
const _TEX_1400x1080 := preload("res://Images/UI/Panel/panel_1400x1080.png")
const _TEX_1680x1080 := preload("res://Images/UI/Panel/panel_1680x1080.png")
const _TEX_1980x1080 := preload("res://Images/UI/Panel/panel_1980x1080.png")
const _TEX_1920x800 := preload("res://Images/UI/Panel/panel_1920x800.png")
const _TEX_1920x600 := preload("res://Images/UI/Panel/panel_1920x600.png")
const _TEX_1920x320 := preload("res://Images/UI/Panel/panel_1920x320.png")
const _TEX_1920x144 := preload("res://Images/UI/Panel/panel_1920x144.png")

## [寬高比, 對應貼圖] 清單,_panel_texture_for_size() 用 log 比例距離找最接近的一筆——
## log 距離對「等倍縮放/等倍放大」對稱(例如比例差 2 倍不管是變寬或變窄,距離一樣),
## 直接用寬高比相減在極端瘦長/極端扁寬的素材之間比較會失真。
const _PANEL_TEXTURE_RATIOS: Array[Array] = [
	[320.0 / 1080.0, _TEX_320x1080],
	[400.0 / 1080.0, _TEX_400x1080],
	[600.0 / 1080.0, _TEX_600x1080],
	[800.0 / 1080.0, _TEX_800x1080],
	[1080.0 / 1080.0, _TEX_1080x1080],
	[1200.0 / 1080.0, _TEX_1200x1080],
	[1400.0 / 1080.0, _TEX_1400x1080],
	[1680.0 / 1080.0, _TEX_1680x1080],
	[1980.0 / 1080.0, _TEX_1980x1080],
	[1920.0 / 800.0, _TEX_1920x800],
	[1920.0 / 600.0, _TEX_1920x600],
	[1920.0 / 320.0, _TEX_1920x320],
	[1920.0 / 144.0, _TEX_1920x144],
]

static func _panel_texture_for_size(width: float, height: float) -> Texture2D:
	var target_ratio := width / height
	var best_texture: Texture2D = _PANEL_TEXTURE_RATIOS[0][1]
	var best_distance := INF
	for entry in _PANEL_TEXTURE_RATIOS:
		var distance: float = absf(log(float(entry[0]) / target_ratio))
		if distance < best_distance:
			best_distance = distance
			best_texture = entry[1]
	return best_texture


## 羊皮紙木框彈窗共用文字配色(搭配 apply_parchment_panel 的淺色底,深色系深咖啡才夠
## 對比),取代原本 action_panel.gd/dialogue_box.tscn/ask_battle.tscn 各自手刻同一組顏色值。
const PARCHMENT_TEXT_COLOR := Color(0.28, 0.16, 0.06, 1)
const PARCHMENT_SUBTITLE_COLOR := Color(0.4, 0.29, 0.18, 1)

## 羊皮紙面板底下清單/卡片(action_panel.gd 的清單列、CharacterAvatarCard、PartyEdit
## CharacterCard 等)共用的行/卡片配色——半透明暖棕底 + 深咖啡邊框,取代原本各處沿用的
## 深藍底(Color(0.13, 0.15, 0.21, ...) 那組配色,那組是給深色面板配的,套在羊皮紙底上會
## 深藍色塊格格不入。SELECTED_BORDER 沿用原本的金色系,金色在羊皮紙底上一樣醒目,不用改。
const PARCHMENT_ROW_BG := Color(0.55, 0.42, 0.26, 0.28)
const PARCHMENT_ROW_BORDER := Color(0.35, 0.22, 0.1, 0.45)
const PARCHMENT_ROW_SHADOW := Color(0.2, 0.12, 0.05, 0.2)
const PARCHMENT_SELECTED_BORDER := Color(0.95, 0.75, 0.4, 1)

## 羊皮紙底下的行/卡片樣式建構器,呼叫端只需要決定邊框顏色(平常用
## PARCHMENT_ROW_BORDER,選中/高亮狀態用 PARCHMENT_SELECTED_BORDER)。
static func parchment_row_style(
	border_color: Color = PARCHMENT_ROW_BORDER,
	border_width: int = 1,
	corner_radius: int = 10,
	content_margin_h: float = 12.0,
	content_margin_v: float = 8.0,
	shadow_size: int = 6
) -> StyleBoxFlat:
	return bordered_panel(
		PARCHMENT_ROW_BG, border_color, border_width, corner_radius,
		content_margin_h, content_margin_v, shadow_size, PARCHMENT_ROW_SHADOW
	)

## 羊皮紙木框面板樣式(action_panel.tscn 原本內嵌的 StyleBoxTexture 抽出來共用,跟
## apply_wood_plaque_button 一樣是「呼叫端在 _ready() 呼叫一次」的做法,取代場景檔各自
## 內嵌一份 StyleBoxTexture SubResource)。panel_width/panel_height 是呼叫端面板的設計
## 寬高(讀 .tscn 的 offset/custom_minimum_size 算出來,不是拿 Control.size 在 _ready()
## 現場量——版面在容器裡的最終大小要等排版跑完才確定,_ready() 當下不保證正確),用來
## 挑選比例最接近的貼圖(見 _panel_texture_for_size())。texture_margin 是依貼圖家族
## 共用的邊框厚度量出來的固定值,不開放呼叫端調整(改了九宮格切片會跑掉);content_margin
## (面板內容跟邊框的留白)每個用途大小差很多(彈出清單面板 vs 對話框窄長條 vs 小型詢問
## 彈窗),留給呼叫端依面板尺寸傳入。
static func apply_parchment_panel(
	panel: Control,
	panel_width: float,
	panel_height: float,
	content_margin_left: float = 30.0,
	content_margin_top: float = 50.0,
	content_margin_right: float = 30.0,
	content_margin_bottom: float = 50.0
) -> void:
	var style := StyleBoxTexture.new()
	style.texture = _panel_texture_for_size(panel_width, panel_height)
	style.texture_margin_left = 30.0
	style.texture_margin_top = 50.0
	style.texture_margin_right = 30.0
	style.texture_margin_bottom = 80.0
	style.content_margin_left = content_margin_left
	style.content_margin_top = content_margin_top
	style.content_margin_right = content_margin_right
	style.content_margin_bottom = content_margin_bottom
	panel.add_theme_stylebox_override("panel", style)


const WOOD_BUTTON_NORMAL_TEXTURE := preload("res://Images/UI/button/wood_button_normal.png")
const WOOD_BUTTON_HOVER_TEXTURE := preload("res://Images/UI/button/wood_button_hover.png")
const WOOD_BUTTON_PRESSED_TEXTURE := preload("res://Images/UI/button/wood_button_pressed.png")
const WOOD_BUTTON_DISABLED_TEXTURE := preload("res://Images/UI/button/wood_button_disabled.png")
const WOOD_BUTTON_FONT := preload("res://Fonts/NotoSerifTC-Bold.ttf")

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

	button.add_theme_font_override("font", WOOD_BUTTON_FONT)
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
