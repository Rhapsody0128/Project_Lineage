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
## (見 apply_parchment_panel 的 panel.png)的暖色調不搭。呼叫端在 _ready() 對面板
## 內的 ScrollContainer 呼叫一次即可套用做舊木紋配色的捲軸——軌道用半透明羊皮紙色,
## 握把用木紋深棕色,圓角柔化邊緣,不是系統預設那種生硬的直角灰條。
##
## _SCROLLBAR_THICKNESS 對應的是 content_margin_h,不是隨便選的裝飾參數——
## ScrollContainer 內部用 v_scroll.get_combined_minimum_size().x 決定捲軸實際保留的
## 寬度(見 Godot scroll_container.cpp),而 StyleBoxFlat 的 minimum_size 就是
## content_margin 本身。四顆 bordered_panel() 呼叫原本沒傳 content_margin_h(預設
## 0.0),等於捲軸寬度算出來是 0——顏色/圓角都有設定但寬度收縮成 0px,畫面上直接
## 看不到,不是顏色不夠深的問題。這裡固定給一個非零寬度撐開它。
const _SCROLLBAR_THICKNESS := 4.0

static func apply_parchment_scrollbar(scroll_container: ScrollContainer) -> void:
	var v_scroll := scroll_container.get_v_scroll_bar()
	v_scroll.add_theme_stylebox_override("scroll", bordered_panel(
		Color(0.55, 0.42, 0.26, 0.16), Color(0.35, 0.22, 0.1, 0.3), 1, 6, _SCROLLBAR_THICKNESS
	))
	v_scroll.add_theme_stylebox_override("grabber", bordered_panel(
		Color(0.42, 0.28, 0.14, 0.85), Color(0.24, 0.14, 0.06, 0.9), 1, 6, _SCROLLBAR_THICKNESS
	))
	v_scroll.add_theme_stylebox_override("grabber_highlight", bordered_panel(
		Color(0.52, 0.36, 0.18, 0.95), Color(0.28, 0.16, 0.08, 1), 1, 6, _SCROLLBAR_THICKNESS
	))
	v_scroll.add_theme_stylebox_override("grabber_pressed", bordered_panel(
		Color(0.32, 0.21, 0.1, 1), Color(0.2, 0.12, 0.05, 1), 1, 6, _SCROLLBAR_THICKNESS
	))


## 羊皮紙面板底圖只有一張原圖(Images/UI/Panel/panel.png,實際像素 1920x1080)。
## 不管呼叫端面板是什麼寬高,一律不拉伸整張圖去塞——拉伸會讓四邊手繪的破損毛邊變形。
## 改成依面板寬高比從原圖中央「裁」出一塊同比例的區域當背景(等同 CSS background-size:
## cover 置中裁切,裁下來的區域是原圖的實際像素,不縮放不變形):面板比原圖寬(例如
## 1920x300 這種扁長條),裁滿原圖寬度、只取中央那一截高度;面板比原圖窄(例如 300x1080
## 這種瘦長條),裁滿原圖高度、只取中央那一截寬度。_panel_crop_region() 算出來的區域交給
## AtlasTexture 當 StyleBoxTexture.texture,texture_margin(九宮格邊框厚度)吃的是裁切後
## 區域的像素,不是原圖整體。

const _TEX_PARCHMENT := preload("res://Images/UI/Panel/panel.png")

static func _panel_crop_region(width: float, height: float) -> Rect2:
	var tex_size := Vector2(_TEX_PARCHMENT.get_size())
	var target_ratio := width / height
	var master_ratio := tex_size.x / tex_size.y
	var region_size: Vector2
	if target_ratio >= master_ratio:
		region_size = Vector2(tex_size.x, tex_size.x / target_ratio)
	else:
		region_size = Vector2(tex_size.y * target_ratio, tex_size.y)
	var region_pos := Vector2.ZERO
	return Rect2(region_pos, region_size)


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
## 從原圖裁出對應比例的區域(見 _panel_crop_region())。面板內容跟邊框的留白固定用
## _CONTENT_MARGIN(全專案唯一一處定義),呼叫端不能個別傳值覆寫——之前開放四邊各自
## 傳參數,結果各面板各自兜出一組數字(有的還在外面另包一層 MarginContainer 疊加),
## 同一顆元件在不同畫面內距不一致還很難追。內容需要比這個留白更寬鬆的呼吸空間,一律在
## 面板「內部」自己疊 MarginContainer/PADDING 常數(見 character_detail_view.gd 的
## TAB_CONTENT_PADDING),不要回頭改這裡的簽名。
##
## panel_width/panel_height 純粹是「第一次套用」時的裁切比例猜測值,只影響背景貼圖好不好
## 看,這個函式永遠不會、也不該去讀寫 panel 的 custom_minimum_size 或任何 layout 屬性——
## 決定面板實際尺寸是呼叫端/面板內容自己的責任(例如 CharacterDetailView 自己在 _ready()
## 套 custom_minimum_size.x,見該檔案 PANEL_WIDTH 註解),這裡只管羊皮紙視覺,不能拿來當
## 「順便設定大小」的手段。呼叫端不知道最終尺寸時(例如高度交給父層 Container 決定,實際
## 高度要等排版跑完才確定)可以直接傳 0.0,_set_parchment_style() 會直接跳過第一次套用,
## 純等下面的 panel.resized 用真實尺寸補上——不用勉強猜一個數字。傳了猜測值但跟實際顯示
## 比例差很多也沒關係(例如 marriage_proposal_panel.gd 的 PickerPanel,實際寬高由
## RightPanel 扣掉 DetailPanel 寬度後才算得出來,猜測值必然不準):這裡多接一手
## panel.resized——排版跑完、面板真正定案的大小出來之後,用 panel.size(而不是呼叫端猜的
## 值)重新套一次,裁切永遠跟顯示框同比例,不管容器怎麼排版都不會走樣;呼叫端不用自己去
## 反推正確的設計寬高。

const _TEXTURE_MARGIN_LEFT := 5.0
const _TEXTURE_MARGIN_TOP := 5.0
const _TEXTURE_MARGIN_RIGHT := 5.0
const _TEXTURE_MARGIN_BOTTOM := 5.0

const _CONTENT_MARGIN := 30.0

static func apply_parchment_panel(panel: Control, panel_width: float, panel_height: float) -> void:
	_set_parchment_style(panel, panel_width, panel_height)
	panel.resized.connect(func():
		_set_parchment_style(panel, panel.size.x, panel.size.y)
	)


static func _set_parchment_style(panel: Control, panel_width: float, panel_height: float) -> void:
	if panel_width <= 0.0 or panel_height <= 0.0:
		return

	var region := _panel_crop_region(panel_width, panel_height)

	var atlas := AtlasTexture.new()
	atlas.atlas = _TEX_PARCHMENT
	atlas.region = region

	var margin_scale_h := minf(1.0, region.size.x / (_TEXTURE_MARGIN_LEFT + _TEXTURE_MARGIN_RIGHT))
	var margin_scale_v := minf(1.0, region.size.y / (_TEXTURE_MARGIN_TOP + _TEXTURE_MARGIN_BOTTOM))

	var style := StyleBoxTexture.new()
	style.texture = atlas
	style.texture_margin_left = _TEXTURE_MARGIN_LEFT * margin_scale_h
	style.texture_margin_right = _TEXTURE_MARGIN_RIGHT * margin_scale_h
	style.texture_margin_top = _TEXTURE_MARGIN_TOP * margin_scale_v
	style.texture_margin_bottom = _TEXTURE_MARGIN_BOTTOM * margin_scale_v

	style.content_margin_left = _CONTENT_MARGIN
	style.content_margin_top = _CONTENT_MARGIN
	style.content_margin_right = _CONTENT_MARGIN
	style.content_margin_bottom = _CONTENT_MARGIN
	panel.add_theme_stylebox_override("panel", style)


## 分隔線樣式:不套羊皮紙面板,只在單一邊畫一條線分隔相鄰區塊,背景透明——用於「整包內容
## 本來就要自然往下長,不需要各自獨立一顆固定尺寸面板」的場合(例如 marriage_proposal_panel.gd/
## stronghold_marriage_panel.gd 拿掉 apply_parchment_panel() 之後,左側區塊在右邊畫一條線
## 分隔右側欄,右側欄上方區塊在下面畫一條線分隔下方區塊)。最後一個區塊(沒有下一個區塊接著)
## 不需要呼叫這裡,維持無邊框即可。
const DIVIDER_COLOR := Color(0.4, 0.29, 0.18, 0.5)

## 完全透明、無邊框——蓋掉引擎預設 PanelContainer 深色底(不套的話會露出一塊跟羊皮紙底
## 不搭的黑底),用在「最後一塊、後面沒有區塊接著,不需要分隔線」的場合。
static func transparent_panel_style(content_margin: float = 16.0) -> StyleBoxFlat:
	return bordered_panel(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, content_margin, content_margin)

static func right_border_style(content_margin: float = 16.0, border_width: int = 2, border_color: Color = DIVIDER_COLOR) -> StyleBoxFlat:
	var style := bordered_panel(Color(0, 0, 0, 0), border_color, 0, 0, content_margin, content_margin)
	style.border_width_right = border_width
	return style

static func bottom_border_style(content_margin: float = 16.0, border_width: int = 2, border_color: Color = DIVIDER_COLOR) -> StyleBoxFlat:
	var style := bordered_panel(Color(0, 0, 0, 0), border_color, 0, 0, content_margin, content_margin)
	style.border_width_bottom = border_width
	return style


const WOOD_BUTTON_NORMAL_TEXTURE := preload("res://Images/UI/button/wood_button_normal.png")
const WOOD_BUTTON_HOVER_TEXTURE := preload("res://Images/UI/button/wood_button_hover.png")
const WOOD_BUTTON_PRESSED_TEXTURE := preload("res://Images/UI/button/wood_button_pressed.png")
const WOOD_BUTTON_DISABLED_TEXTURE := preload("res://Images/UI/button/wood_button_disabled.png")

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


## 根據地面板/彈出式面板內文字按鈕的共用木牌樣式(建造/升級/打造/確認等),取代原本
## Scenes/Base/base_action_panel.gd 私有的 _style_button()——這套按鈕外觀不只一個場景腳本
## 需要,搬到這裡讓 Scenes/ 底下任何面板都能直接呼叫。SIZE_SHRINK_BEGIN 是關鍵——放進
## VBoxContainer 時,對子節點的橫向(交叉軸)預設會撐滿整個面板寬度,不設這個的話木牌貼圖
## 會被硬拉成一整條很長的長方形,不是圖片原本的比例;設成 SHRINK_BEGIN 後按鈕只會跟內容
## (文字+邊距)一樣寬,靠左對齊——放進 HBoxContainer(例如 ActionPanel 標題列)裡則單純
## 避免被撐滿,同樣適用。
static func style_panel_action_button(button: Button) -> void:
	apply_wood_plaque_button(button, 16.0, 6.0)
	button.add_theme_font_size_override("font_size", 16)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN


static func _wood_button_stylebox(texture: Texture2D, content_margin_h: float, content_margin_v: float) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.content_margin_left = content_margin_h
	style.content_margin_right = content_margin_h
	style.content_margin_top = content_margin_v
	style.content_margin_bottom = content_margin_v
	return style
