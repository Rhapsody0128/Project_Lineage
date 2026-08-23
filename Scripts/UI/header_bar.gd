class_name HeaderBar
extends Control

# =========================================================
# 大地圖/根據地等場景共用的頂部列,完全自給自足——呼叫端只要
# `HeaderBar.new(); some_canvas_layer.add_child(header)` 就好,不需要另外接訊號或每幀
# 同步任何狀態:
# - 左側世界時間文字,HeaderBar 自己在 _process() 呼叫 WorldTimeStore.controller.advance()
#   推進世界時間、再更新文字,呼叫端不用管——這也代表世界時間「是否會走」直接綁在「這個
#   場景有沒有掛 HeaderBar」,不是綁在個別場景腳本(過去只有 map.gd._process() 會推進,
#   根據地按暫停鈕會顯示播放中但時間實際上沒在走,是舊版留下的不一致)。
# - 旁邊的時間播放列(TIMEPLAYER 木牌美術,見下方常數說明)點暫停/▶1x/2x/3x,或鍵盤
#   1/2/3/4,都直接呼叫 WorldTimeStore.set_speed_level() + set_playing();Space 鍵直接呼叫
#   WorldTimeStore.toggle_playing()——HeaderBar 自己是全域唯一的倍速/暫停控制入口,不會
#   有第二條路徑改到同一份狀態,所以不需要像 CharacterPanel 那樣經由訊號讓呼叫端轉發。
# - 右上角一顆漢堡選單按鈕,點開下拉選單可直接切去戰報列表/隊伍編輯/角色列表,或直接
#   跳回主選單,不用像 main.gd 那樣得先繞回主選單才能到這些畫面。切場景一律走
#   NavigationStore.go_to(),party_edit.gd/battle_report_list.gd/character_roster.gd 的
#   返回鍵才能正確回到這裡,而不是寫死回 Scenes/main.tscn。
#
# 跟 CharacterSortFilterBar 一樣是純程式碼組畫面的共用元件。每次進場景都是全新節點
# (HeaderBar.new()),_ready() 建立按鈕時直接讀 WorldTimeStore.speed_level 同步外觀,
# 不需要呼叫端額外做任何同步——倍速/暫停是全域狀態,離開/返回場景不會重置。
# =========================================================

const _HEIGHT := 52.0

const _BG_COLOR := Color(0.13, 0.15, 0.21, 0.95)
const _BORDER_COLOR := Color(0.36, 0.4, 0.56, 1)
const _BUTTON_BG := Color(0.2, 0.24, 0.36, 1)
const _BUTTON_BORDER := Color(0.4, 0.46, 0.66, 1)
const _BUTTON_HOVER_BG := Color(0.27, 0.32, 0.46, 1)
const _BUTTON_HOVER_BORDER := Color(0.55, 0.62, 0.85, 1)
const _BUTTON_PRESSED_BG := Color(0.16, 0.19, 0.28, 1)
const _TIME_FONT_COLOR := Color(0.95, 0.9, 0.72, 1)

const _ID_REPORTS := 0
const _ID_PARTY := 1
const _ID_CHARACTERS := 2
const _ID_NEWS := 3
const _ID_MAIN_MENU := 4
const _ID_SAVE := 5
const _ID_LOAD := 6
const _ID_QUESTS := 7
const _ID_NATIONS := 8

## 時間播放列美術(Images/UI/other/TIMEPLAYER.png,1024x559)——由上到下 4 排,每排是
## 一張完整的木牌長條圖,分別代表「暫停/▶1x/2x/3x」四種互斥狀態整排的樣子(哪顆按鈕在
## 發光是畫死在圖裡的,不是可疊加的獨立圖層)。座標是逐排用像素掃描量出來的實際內容
## 範圍,4 排之間有不等寬的留白,並非簡單的 559/4 均分,所以每排各自列一個 Rect2,不用
## 公式算。DEMO(100 倍速,speed_level 4)這張圖沒有對應的第五排美術,見
## _current_time_player_state() 的處理方式。
const _TIME_PLAYER_TEXTURE_PATH := "res://Images/UI/other/TIMEPLAYER.png"
const _TIME_PLAYER_ROW_RECTS := {
	"paused": Rect2(0, 29, 1024, 118),
	"1x": Rect2(0, 157, 1024, 119),
	"2x": Rect2(0, 285, 1024, 119),
	"3x": Rect2(0, 413, 1024, 118),
}
## 圖上 4 顆按鈕(暫停/▶/2X/3X)在整排寬度(1024)裡的 x 範圍,換算成 0~1 的比例,
## 用來在顯示用的 TextureRect 上疊透明點擊區——4 排的按鈕位置是對齊的,量一排就夠套用
## 全部狀態。範圍比按鈕實際發光區再往外加一點邊界,點擊判定不用卡到像素邊緣。
const _TIME_PLAYER_HIT_FRACTIONS := {
	"paused": Vector2(130.0 / 1024.0, 286.0 / 1024.0),
	"1x": Vector2(343.0 / 1024.0, 497.0 / 1024.0),
	"2x": Vector2(552.0 / 1024.0, 705.0 / 1024.0),
	"3x": Vector2(760.0 / 1024.0, 913.0 / 1024.0),
}
const _TIME_PLAYER_DISPLAY_SIZE := Vector2(340.0, 40.0)

## 「資源」「隊伍」這類展開式狀態面板共用的樣式,見 _add_status_toggle()。
const _PANEL_BG := Color(0.1, 0.12, 0.18, 0.97)
const _PANEL_BORDER := Color(0.4, 0.46, 0.66, 1)
const _PANEL_GAP := 8.0
const _HP_BAR_BG := Color(0.1, 0.1, 0.12)
const _HP_BAR_FILL := Color(0.45, 0.85, 0.45)
const _HP_BAR_CORNER_RADIUS := 5
const _PARTY_AVATAR_SIZE := Vector2(40, 40)

## 隊伍/資源兩塊子清單各自固定高度(超出用 ScrollContainer 內部捲動),讓面板整體
## 高度固定不再隨內容筆數變動——見 add_status_button() 說明。
const _STATUS_PARTY_HEIGHT := 180.0
const _STATUS_RESOURCE_HEIGHT := 120.0
const _STATUS_FLOW_SEPARATION := 10

## 鍵盤 1/2/3/4 → 倍速等級,見 _unhandled_input()。
const _KEY_TO_SPEED_LEVEL := {KEY_1: 1, KEY_2: 2, KEY_3: 3, KEY_4: 4}

var time_label: Label
## 時間播放列的顯示用貼圖(隨狀態切換 AtlasTexture.region,見 _update_time_player_display()),
## 疊在上面的 4 個透明點擊區只在建構時用一次,不需要存成員變數。
var _time_player_atlas: AtlasTexture

## 日期/時間播放列(包在 left_group 裡)跟漢堡選單所在的橫向排列,add_menu_button()
## 插入的額外按鈕也塞進這裡,見該函式。
var _row: HBoxContainer

## add_status_button() 建立的狀態面板,存成成員變數而非局部變數捕捉進 lambda——
## WorldTimeStore.day_passed/BaseResourceStore.changed 是全域訊號,HeaderBar 卻是每次
## 進場景就整顆重建(見上方說明),若用 lambda 捕捉局部變數連進這兩個全域訊號,連線的
## Callable 沒有綁定任何 Object 當 target,離開場景時 Godot 不會自動斷線(自動斷線只認
## 「Callable 綁定 self 方法」這種連線),舊 HeaderBar 的連線會一直留著,下次全域訊號觸發
## 時就會摸到已經被釋放的 panel/content,炸出「Lambda capture was freed」或「Invalid
## access ... on a base object of type 'Nil'」。改綁 self 的具名方法(_on_status_*)才能讓
## Godot 在這個 HeaderBar 被釋放時自動把連線一起清掉。
var _status_button: Button
var _status_panel: PanelContainer
## 隊伍列表/資源清單各自的內容容器(分別包在固定高度的 ScrollContainer 裡,見
## add_status_button()),_refresh_status() 只清空重建這兩個,不動外層固定結構。
var _status_party_list: VBoxContainer
var _status_resource_flow: HFlowContainer


func _ready() -> void:
	anchor_left = 0.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = 0.0
	offset_right = 0.0
	offset_top = 0.0
	offset_bottom = _HEIGHT
	grow_horizontal = Control.GROW_DIRECTION_BOTH

	var bg := PanelContainer.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_theme_stylebox_override("panel", UiStyle.bordered_panel(
		_BG_COLOR, _BORDER_COLOR, 2, 0, 20.0, 8.0
	))
	add_child(bg)

	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 12)
	bg.add_child(_row)

	## 日期文字 + 時間播放列包在同一個會展開的 HBoxContainer 裡,兩者本身都不 expand——
	## 這樣播放列會緊貼在日期文字右邊(取代舊版貼在文字裡的 ⏸️/▶️/⏩ 圖示),而不是被
	## 單獨 expand 的 time_label 推到 _row 最右邊、離日期文字很遠。這個 left_group 才是
	## 真正吃掉 _row 剩餘空間、把漢堡選單等按鈕推去右側的那個節點。
	var left_group := HBoxContainer.new()
	left_group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_group.add_theme_constant_override("separation", 12)
	_row.add_child(left_group)

	time_label = Label.new()
	time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	time_label.add_theme_font_size_override("font_size", 22)
	time_label.add_theme_color_override("font_color", _TIME_FONT_COLOR)
	time_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	time_label.add_theme_constant_override("outline_size", 4)
	left_group.add_child(time_label)

	left_group.add_child(_build_time_player_control())

	var menu_button := MenuButton.new()
	menu_button.text = "功能"
	menu_button.focus_mode = Control.FOCUS_NONE
	menu_button.custom_minimum_size = Vector2(48, 36)
	menu_button.add_theme_font_size_override("font_size", 20)
	menu_button.add_theme_stylebox_override("normal", UiStyle.bordered_panel(_BUTTON_BG, _BUTTON_BORDER, 2, 8))
	menu_button.add_theme_stylebox_override("hover", UiStyle.bordered_panel(_BUTTON_HOVER_BG, _BUTTON_HOVER_BORDER, 2, 8))
	menu_button.add_theme_stylebox_override("pressed", UiStyle.bordered_panel(_BUTTON_PRESSED_BG, _BUTTON_BORDER, 2, 8))
	_row.add_child(menu_button)

	var popup := menu_button.get_popup()
	popup.add_item("戰報", _ID_REPORTS)
	popup.add_item("隊伍", _ID_PARTY)
	popup.add_item("角色", _ID_CHARACTERS)
	popup.add_item("消息", _ID_NEWS)
	popup.add_item("任務", _ID_QUESTS)
	popup.add_item("國家關係", _ID_NATIONS)
	popup.add_item("存檔", _ID_SAVE)
	popup.add_item("讀檔", _ID_LOAD)
	popup.add_item("主選單", _ID_MAIN_MENU)
	popup.id_pressed.connect(_on_menu_id_pressed)


## 建一個固定尺寸(_TIME_PLAYER_DISPLAY_SIZE)的容器:底層 TextureRect 顯示 TIMEPLAYER
## 木牌美術目前狀態對應的那一排(見 _update_time_player_display()),上面疊 4 個沒有
## 樣式、只負責吃點擊的透明按鈕,座標用 _TIME_PLAYER_HIT_FRACTIONS 換算——4 排美術的
## 按鈕位置對齊,疊一份透明按鈕就能套用全部狀態,不用每排各自疊一份。
func _build_time_player_control() -> Control:
	var container := Control.new()
	container.custom_minimum_size = _TIME_PLAYER_DISPLAY_SIZE

	_time_player_atlas = AtlasTexture.new()
	_time_player_atlas.atlas = load(_TIME_PLAYER_TEXTURE_PATH) as Texture2D

	var texture_rect := TextureRect.new()
	texture_rect.texture = _time_player_atlas
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.add_child(texture_rect)

	_add_time_player_hit_zone(container, "paused", _on_time_player_pause_pressed)
	_add_time_player_hit_zone(container, "1x", _on_time_player_speed_pressed.bind(1))
	_add_time_player_hit_zone(container, "2x", _on_time_player_speed_pressed.bind(2))
	_add_time_player_hit_zone(container, "3x", _on_time_player_speed_pressed.bind(3))

	_update_time_player_display()
	return container


## 透明點擊區用空白 StyleBox 蓋掉 Button 預設外觀(不用 flat=true——不同主題下 flat
## 仍可能在 hover/focus 時畫出一點底色,蓋在木牌美術上會很明顯),只留點擊判定跟滑鼠
## 手勢游標。anchor 用比例(不是像素 offset)卡位置,_TIME_PLAYER_DISPLAY_SIZE 之後如果
## 調整寬高,點擊區會跟著等比例縮放,不會跑掉。
func _add_time_player_hit_zone(container: Control, state: String, callback: Callable) -> void:
	var fraction: Vector2 = _TIME_PLAYER_HIT_FRACTIONS[state]
	var hit := Button.new()
	hit.focus_mode = Control.FOCUS_NONE
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hit.anchor_left = fraction.x
	hit.anchor_right = fraction.y
	hit.anchor_top = 0.0
	hit.anchor_bottom = 1.0
	hit.offset_left = 0.0
	hit.offset_right = 0.0
	hit.offset_top = 0.0
	hit.offset_bottom = 0.0
	var empty_style := StyleBoxEmpty.new()
	hit.add_theme_stylebox_override("normal", empty_style)
	hit.add_theme_stylebox_override("hover", empty_style)
	hit.add_theme_stylebox_override("pressed", empty_style)
	hit.add_theme_stylebox_override("focus", empty_style)
	hit.pressed.connect(callback)
	container.add_child(hit)


## 點「暫停」明確設成暫停,不是切換——跟 Space 鍵的 toggle_playing() 語意不同(見
## _unhandled_input()),但共用同一顆 controller.is_playing。
func _on_time_player_pause_pressed() -> void:
	WorldTimeStore.set_playing(false)


## 點▶1x/2x/3x 明確設成「這個倍速 + 播放中」,不是只改倍速——舊版倍速按鈕跟播放/暫停
## 是兩條獨立狀態(選 2x 不會自動恢復播放),但新版木牌美術把兩者畫成同一組互斥按鈕,
## 點下去理應兩者一起生效,鍵盤 1/2/3/4(見 _unhandled_input())也走同一段邏輯。
func _on_time_player_speed_pressed(level: int) -> void:
	WorldTimeStore.set_speed_level(level)
	WorldTimeStore.set_playing(true)


## 目前應該顯示哪一排:暫停中一律顯示「paused」排,不看倍速等級;播放中依 speed_level
## 對應排數。DEMO(4)沒有第五排美術,借用「3x」排顯示(不影響 play_speed_multiplier
## 實際還是 100 倍,只是外觀上顯示不出「比 3x 更快」的差異)。
func _current_time_player_state() -> String:
	if not WorldTimeStore.controller.is_playing:
		return "paused"
	match WorldTimeStore.speed_level:
		2:
			return "2x"
		3, 4:
			return "3x"
		_:
			return "1x"


func _update_time_player_display() -> void:
	_time_player_atlas.region = _TIME_PLAYER_ROW_RECTS[_current_time_player_state()]


## 世界時間的實際推進(WorldTimeStore.controller.advance())綁在這裡,不是綁在個別
## 場景腳本——HeaderBar 是唯一的倍速/暫停控制入口,同時掛在大地圖(map.gd)跟根據地
## (base.gd),只要場景掛了 HeaderBar,is_playing 為真時世界時間就會走,不會出現「按了
## 播放、圖示也變了,但時間沒在跑」的不一致(根據地過去沒有場景腳本呼叫 advance(),
## 只有大地圖的 map.gd._process() 會推進)。advance() 內部本來就會檢查 is_playing,
## 暫停時呼叫也不會動,這裡不用另外判斷。
func _process(delta: float) -> void:
	WorldTimeStore.controller.advance(delta * WorldTimeStore.play_speed_multiplier)
	_update_time_label()
	_update_time_player_display()


## 播放/暫停狀態已經改由旁邊的時間播放列(TIMEPLAYER 木牌美術)顯示,這裡只單純顯示
## 日期文字,不再需要 ⏸️/▶️/⏩ 這組 emoji 圖示。
func _update_time_label() -> void:
	time_label.text = WorldTimeStore.get_display_string()


## Space 切換播放/暫停(跟時間播放列的「暫停」按鈕不同,是 toggle 不是明確設定,維持
## 原本「按一下暫停/再按一下恢復原本倍速」的手感);1/2/3/4 切倍速等級,跟滑鼠點▶/2X/3X
## 走同一段邏輯(_on_time_player_speed_pressed())——選倍速的同時也會恢復播放。4 是
## DEMO(100 倍速),時間播放列沒有對應的可見按鈕(見 _current_time_player_state()),
## 仍保留鍵盤 4 當隱藏入口。這支 HeaderBar 是全域唯一的倍速/暫停控制入口,所在場景不需要
## 自己再接一份鍵盤快捷鍵。
func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_SPACE:
		WorldTimeStore.toggle_playing()
	elif _KEY_TO_SPEED_LEVEL.has(key_event.keycode):
		_on_time_player_speed_pressed(_KEY_TO_SPEED_LEVEL[key_event.keycode])


## 給需要在 HEADER 上多掛一顆下拉選單的場景用,塞在漢堡選單(☰)前面、倍速按鈕後面,
## 回傳的 MenuButton 由呼叫端自己用 get_popup() 填內容/接訊號——HeaderBar 本身不知道
## 內容是什麼,維持通用元件不綁特定場景的資料。
func add_menu_button(button_text: String) -> MenuButton:
	var button := MenuButton.new()
	button.text = button_text
	_style_header_button(button)
	_row.add_child(button)
	_row.move_child(button, _row.get_child_count() - 2)
	return button


## add_menu_button()/_add_status_toggle() 共用的按鈕外觀(邊框樣式/字級/最小尺寸),
## 避免兩處各自複製貼上同一段 stylebox override。
func _style_header_button(button: BaseButton, min_width: float = 64.0) -> void:
	## 不讓按鈕搶鍵盤焦點,避免 Space 被 focus 住的按鈕內建 ui_accept 處理掉,誤觸
	## 「詳細」等展開面板按鈕的 toggled、把面板關掉。
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(min_width, 36)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_stylebox_override("normal", UiStyle.bordered_panel(_BUTTON_BG, _BUTTON_BORDER, 2, 8))
	button.add_theme_stylebox_override("hover", UiStyle.bordered_panel(_BUTTON_HOVER_BG, _BUTTON_HOVER_BORDER, 2, 8))
	button.add_theme_stylebox_override("pressed", UiStyle.bordered_panel(_BUTTON_PRESSED_BG, _BUTTON_BORDER, 2, 8))


## 「資源」「隊伍」這類可展開查看目前狀態的按鈕共用的收合面板。跟 add_menu_button()
## 回傳的 MenuButton 不同——PopupMenu 點擊面板以外的地方會自動收合,不符合「展開後點
## 其他地方不收回,再點一次按鈕才收回」的需求,所以改用一般 Button(toggle_mode)搭配
## 手動控制顯示/隱藏的 PanelContainer:toggle_mode 的按鈕本來就不會因為點擊別處而自動
## 彈起,天生符合這個需求,不用額外處理「點擊面板外」的邏輯。
##
## 面板本身掛在 HeaderBar 自己底下(跟 bg 同一層),不會被 52px 高度裁掉(HeaderBar
## 是普通 Control,沒設 clip_contents);疊層順序上晚於 bg 加入,畫面上蓋在 bg 之上,
## 而整個 HeaderBar 又是掛在呼叫端場景的 CanvasLayer 裡,天生蓋在場景內容之上。呼叫端
## (add_status_button())自己接 toggled 訊號決定何時呼叫 _reposition_status_panel()
## 重新定位——面板本身寬高固定(見 add_status_button()),不需要每次重新量測。
func _add_status_toggle(button_text: String, panel_min_width: float) -> Dictionary:
	var button := Button.new()
	button.text = button_text
	button.toggle_mode = true
	_style_header_button(button)
	_row.add_child(button)
	_row.move_child(button, _row.get_child_count() - 2)

	var panel := PanelContainer.new()
	panel.visible = false
	panel.custom_minimum_size = Vector2(panel_min_width, 0)
	panel.add_theme_stylebox_override("panel", UiStyle.bordered_panel(_PANEL_BG, _PANEL_BORDER, 2, 10, 12.0, 10.0))
	add_child(panel)

	return {"button": button, "panel": panel}


## 面板寬高固定(呼叫端建立時傳入的 panel_min_width + 內部兩塊 ScrollContainer 固定
## 高度算出來的高度),定位只需要靠右緣切齊按鈕右緣往下展開——按鈕群本來就貼著
## HeaderBar 右側,面板往左展開才不會超出視窗右邊界。
func _reposition_status_panel(button: Control, panel: Control) -> void:
	panel.size = panel.get_combined_minimum_size()
	var button_rect := button.get_global_rect()
	panel.global_position = Vector2(
		button_rect.position.x + button_rect.size.x - panel.size.x,
		button_rect.position.y + button_rect.size.y + _PANEL_GAP
	)


## 「狀態」面板整合小隊(Scripts/Autoload/party_store.gd)跟根據地資源
## (Scripts/Autoload/base_resource_store.gd)兩份全域狀態,兩者都不是只有單一場景
## 在乎——Scenes/Map/map.gd、Scenes/Base/base.gd 都掛這顆,玩家在大地圖或根據地都能
## 隨時看目前小隊 HP/資源存量,不用特地跑一趟隊伍編輯或根據地。內容由上到下分兩段:
## 上半段隊伍頭像 + HP 血條、下半段資源清單(只列非 0 的資源,只顯示 icon,不顯示
## 中文品項名稱,省版面),各自包一層固定高度的 ScrollContainer、超出用內部捲動——
## 筆數變動(隊員增減/資源種類變化)只會改變可捲動範圍,不會改變面板整體高度,避免
## DEMO 倍速下世界時間每天觸發一次 _on_status_data_changed() 重建內容時面板高度
## 跟著抖動。展開面板時才重建內容,面板開著時資源存量變動(BaseResourceStore.changed)
## 或跨天 HP 自然回復(WorldTimeStore.day_passed)都要即時刷新,不能只在重新展開時才
## 刷新——否則數字早就變了,畫面卻停在打開當下那一刻的舊值。戰鬥造成的 HP 變動不需要
## 另外接訊號更新——戰鬥發生在 Battle 場景,離開/返回 Map、Base 時 HeaderBar 都是
## 全新節點,面板本來就是收合狀態,下次展開會自然重建成最新數值。
func add_status_button() -> void:
	var parts := _add_status_toggle("詳細", 260.0)
	_status_button = parts["button"]
	_status_panel = parts["panel"]

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	_status_panel.add_child(content)

	var party_scroll := ScrollContainer.new()
	party_scroll.custom_minimum_size = Vector2(0, _STATUS_PARTY_HEIGHT)
	party_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(party_scroll)
	_status_party_list = VBoxContainer.new()
	_status_party_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_party_list.add_theme_constant_override("separation", 6)
	party_scroll.add_child(_status_party_list)

	content.add_child(HSeparator.new())

	var resource_scroll := ScrollContainer.new()
	resource_scroll.custom_minimum_size = Vector2(0, _STATUS_RESOURCE_HEIGHT)
	resource_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(resource_scroll)
	_status_resource_flow = HFlowContainer.new()
	_status_resource_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_resource_flow.add_theme_constant_override("h_separation", _STATUS_FLOW_SEPARATION)
	_status_resource_flow.add_theme_constant_override("v_separation", _STATUS_FLOW_SEPARATION)
	resource_scroll.add_child(_status_resource_flow)

	_status_button.toggled.connect(_on_status_button_toggled)
	BaseResourceStore.changed.connect(_on_status_data_changed)
	WorldTimeStore.day_passed.connect(_on_status_data_changed)


func _on_status_button_toggled(pressed: bool) -> void:
	_status_panel.visible = pressed
	if pressed:
		_refresh_status()


func _on_status_data_changed() -> void:
	if _status_panel.visible:
		_refresh_status()


func _refresh_status() -> void:
	_clear_children(_status_party_list)
	_build_party_rows(_status_party_list)
	_clear_children(_status_resource_flow)
	_build_resource_entries(_status_resource_flow)
	_reposition_status_panel(_status_button, _status_panel)


## 清空容器子節點時要先 remove_child() 立刻脫離容器,再 queue_free()——queue_free()
## 本身是延遲到當幀結束才真的刪除,若只呼叫 queue_free() 就緊接著 add_child() 塞新的
## 子節點,容器在這中間會同時算進「即將刪除的舊節點」跟「剛加入的新節點」,量測出來的
## minimum size 暫時偏大,下一幀舊節點才真的消失、尺寸才變回正確值,肉眼看就是抖動。
func _clear_children(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _build_party_rows(content: VBoxContainer) -> void:
	var party := PartyStore.party
	if party == null or party.characteres.is_empty():
		var label := Label.new()
		label.text = "（尚未編成隊伍）"
		label.add_theme_font_size_override("font_size", 15)
		content.add_child(label)
		return
	for character in party.characteres:
		content.add_child(_build_party_member_row(character))


## 頭像固定給一塊正方形空間(_PARTY_AVATAR_SIZE),兩個 size_flags 都設
## SIZE_SHRINK_CENTER——avatar_frame 是 HBoxContainer 底下的子節點,不特別設的話
## 垂直方向會被撐開填滿整列高度(列高由旁邊 info_column 的名字/血條/HP 數字三行
## 疊起來決定,比 40px 頭像高),導致頭像框變成長方形而不是正方形。
func _build_party_member_row(character: Character) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var avatar_frame := PanelContainer.new()
	avatar_frame.custom_minimum_size = _PARTY_AVATAR_SIZE
	avatar_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	avatar_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	avatar_frame.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	avatar_frame.add_theme_stylebox_override("panel", UiStyle.bordered_panel(Color(0.08, 0.08, 0.1, 0.6), _BUTTON_BORDER, 2, 6))
	avatar_frame.gui_input.connect(_on_party_avatar_gui_input.bind(character))
	row.add_child(avatar_frame)

	var avatar := TextureRect.new()
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if not character.face_path.is_empty():
		avatar.texture = load(character.face_path) as Texture2D
	avatar_frame.add_child(avatar)

	var info_column := VBoxContainer.new()
	info_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_column.add_theme_constant_override("separation", 2)
	row.add_child(info_column)

	var name_label := Label.new()
	name_label.text = character.full_name
	name_label.add_theme_font_size_override("font_size", 15)
	info_column.add_child(name_label)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 12)
	bar.max_value = character.hp_max
	bar.value = character.hp
	bar.show_percentage = false
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = _HP_BAR_FILL
	bar_fill.set_corner_radius_all(_HP_BAR_CORNER_RADIUS)
	bar.add_theme_stylebox_override("fill", bar_fill)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = _HP_BAR_BG
	bar_bg.set_corner_radius_all(_HP_BAR_CORNER_RADIUS)
	bar.add_theme_stylebox_override("background", bar_bg)
	info_column.add_child(bar)

	var hp_label := Label.new()
	hp_label.text = "%d / %d" % [character.hp, character.hp_max]
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hp_label.add_theme_font_size_override("font_size", 12)
	info_column.add_child(hp_label)

	return row


## 點頭像開啟共用角色面板(CharacterPanel 為 autoload 單例),跟戰鬥頭像列
## (battle_party_roster.gd 的 _on_portrait_gui_input())同一套慣例。
func _on_party_avatar_gui_input(input_event: InputEvent, character: Character) -> void:
	if input_event is InputEventMouseButton and input_event.pressed and input_event.button_index == MOUSE_BUTTON_LEFT:
		CharacterPanel.open_for_character(character)


## 只顯示 icon(GameEnums.resource_type_icon_path(),Images/ResourceType/ 底下的圖片,
## 靠 RichTextLabel 的 bbcode [img] 標籤內嵌)+ 數量,不顯示中文品項名稱
## (resource_string_label)——資源種類多,面板寬度有限,icon 已經夠辨識。用
## HFlowContainer 排版:預設由左往右排,單項寬度超出容器剩餘空間就自動換到下一行,
## 不用像過去那樣手動兩兩配對成列。數量後面用括號附上「下月預估增減量」
## (BaseDispatchStore/BaseExchangeStore 的月結算預覽,見 _compute_projected_delta()),
## 正值綠色、負值紅色,方便玩家不用真的跨月就能看出目前派遣/兌換設定的淨效果。
func _build_resource_entries(flow: HFlowContainer) -> void:
	var has_any := false
	var delta := _compute_projected_delta()
	for resource_type in GameEnums.ResourceType.values():
		var amount := BaseResourceStore.get_amount(resource_type)
		if amount == 0:
			continue
		has_any = true
		flow.add_child(_build_resource_icon_label(resource_type, amount, delta.get(resource_type, 0)))

	if not has_any:
		var label := Label.new()
		label.text = "（尚無資源）"
		label.add_theme_font_size_override("font_size", 15)
		flow.add_child(label)


## 合併「派駐生產(含工匠坊配方消耗)」跟「商隊站/黑市每月自動兌換」兩份月結算預覽,
## 給資源清單顯示用。兩份預覽算法各自跟真正的 _on_month_passed() 一致,見
## Scripts/Autoload/base_dispatch_store.gd / base_exchange_store.gd 的
## get_projected_monthly_delta()。
func _compute_projected_delta() -> Dictionary:
	var delta := BaseDispatchStore.get_projected_monthly_delta()
	var exchange_delta := BaseExchangeStore.get_projected_monthly_delta()
	for resource_type in exchange_delta:
		delta[resource_type] = delta.get(resource_type, 0) + exchange_delta[resource_type]
	return delta


func _build_resource_icon_label(resource_type: int, amount: int, delta: int) -> Control:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	## fit_content 算最小尺寸時如果 autowrap 沒關掉,寬度要先知道容器給多少空間才能算
	## wrap 結果,在 HFlowContainer 這種先問子節點 minimum size 再排版的容器裡會卡雞生蛋
	## 蛋生雞,量出來的 minimum size 直接變 0——整排資源看起來像「憑空消失」,不是資料
	## 沒抓到,是這顆 Label 量出來的尺寸是 0x0。關掉 autowrap 讓它用單行內容量真實尺寸。
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.scroll_active = false
	label.add_theme_font_size_override("normal_font_size", 16)
	var icon_tag := "[img=26x26]%s[/img]" % GameEnums.resource_type_icon_path(resource_type)
	var base_text := "%s %d" % [icon_tag, amount]
	if delta == 0:
		label.text = base_text
	else:
		var color_hex := "5FE05F" if delta > 0 else "F05C5C"
		var sign_text := "+%d" % delta if delta > 0 else str(delta)
		label.text = "%s[color=#%s](%s)[/color]" % [base_text, color_hex, sign_text]
	return label


func _on_menu_id_pressed(id: int) -> void:
	match id:
		_ID_REPORTS:
			NavigationStore.go_to("res://Scenes/BattleReportList/battle_report_list.tscn")
		_ID_PARTY:
			NavigationStore.go_to("res://Scenes/PartyEdit/party_edit.tscn")
		_ID_CHARACTERS:
			NavigationStore.go_to("res://Scenes/CharacterRoster/character_roster.tscn")
		_ID_NEWS:
			NavigationStore.go_to("res://Scenes/News/news_list.tscn")
		_ID_QUESTS:
			NavigationStore.go_to("res://Scenes/QuestList/quest_list.tscn")
		_ID_NATIONS:
			NavigationStore.go_to("res://Scenes/NationRelations/nation_relations.tscn")
		_ID_SAVE:
			SaveSlotPicker.open_save_menu()
		_ID_LOAD:
			SaveSlotPicker.open_load_menu()
		_ID_MAIN_MENU:
			NavigationStore.go_to("res://Scenes/main.tscn")
