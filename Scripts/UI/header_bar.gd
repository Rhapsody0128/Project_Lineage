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
# - 旁邊四顆倍速按鈕(1x/2x/3x/DEMO,互斥單選按鈕組)點下去、或鍵盤 1/2/3/4,都直接呼叫
#   WorldTimeStore.set_speed_level();Space 鍵直接呼叫 WorldTimeStore.toggle_playing()——
#   HeaderBar 自己是全域唯一的倍速/暫停控制入口,不會有第二條路徑改到同一份狀態,所以
#   不需要像 CharacterPanel 那樣經由訊號讓呼叫端轉發。
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

## 倍速按鈕的等級 → 顯示文字,4 是 DEMO 用的 100 倍速(見
## Scripts/Autoload/world_time_store.gd 的 set_speed_level())。▶️ 代表一般倍速、
## ⏩ 代表快轉,跟 _update_time_label() 裡播放中/暫停用的 ▶️/⏸️ 圖示呼應,同一套
## 視覺語言。
const _SPEED_LEVEL_LABELS := {1: "▶️ 1x", 2: "⏩ 2x", 3: "⏩ 3x", 4: "⏩ DEMO"}
const _SPEED_BUTTON_BG := Color(0.2, 0.24, 0.36, 1)
const _SPEED_BUTTON_ACTIVE_BG := Color(0.55, 0.32, 0.16, 1)

## 鍵盤 1/2/3/4 → 倍速等級,跟按鈕走同一個路徑:_unhandled_input() 直接按下對應的
## speed_button,觸發它的 toggled 訊號,由 _on_speed_button_toggled() 統一處理,不
## 另外開一條呼叫 WorldTimeStore 的路。
const _KEY_TO_SPEED_LEVEL := {KEY_1: 1, KEY_2: 2, KEY_3: 3, KEY_4: 4}

var time_label: Label
## 等級(1/2/3/4)→ 對應按鈕,單選按鈕組(ButtonGroup)確保同時間只有一顆按下。
var speed_buttons: Dictionary = {}

## 倍速按鈕/漢堡選單所在的橫向排列,add_menu_button() 插入的額外按鈕也塞進這裡,
## 見該函式。
var _row: HBoxContainer


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

	time_label = Label.new()
	time_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	time_label.add_theme_font_size_override("font_size", 22)
	time_label.add_theme_color_override("font_color", _TIME_FONT_COLOR)
	time_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	time_label.add_theme_constant_override("outline_size", 4)
	_row.add_child(time_label)

	var speed_button_group := ButtonGroup.new()
	for level in _SPEED_LEVEL_LABELS.keys():
		var speed_button := Button.new()
		speed_button.text = _SPEED_LEVEL_LABELS[level]
		speed_button.toggle_mode = true
		speed_button.button_group = speed_button_group
		speed_button.custom_minimum_size = Vector2(76, 36)
		speed_button.add_theme_font_size_override("font_size", 16)
		speed_button.add_theme_stylebox_override("normal", UiStyle.bordered_panel(_SPEED_BUTTON_BG, _BUTTON_BORDER, 2, 8))
		speed_button.add_theme_stylebox_override("hover", UiStyle.bordered_panel(_BUTTON_HOVER_BG, _BUTTON_HOVER_BORDER, 2, 8))
		speed_button.add_theme_stylebox_override("pressed", UiStyle.bordered_panel(_SPEED_BUTTON_ACTIVE_BG, _BUTTON_HOVER_BORDER, 2, 8))
		speed_button.toggled.connect(_on_speed_button_toggled.bind(level))
		_row.add_child(speed_button)
		speed_buttons[level] = speed_button
	speed_buttons[WorldTimeStore.speed_level].set_pressed_no_signal(true)

	var menu_button := MenuButton.new()
	menu_button.text = "☰"
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
	popup.add_item("主選單", _ID_MAIN_MENU)
	popup.id_pressed.connect(_on_menu_id_pressed)


## 世界時間的實際推進(WorldTimeStore.controller.advance())綁在這裡,不是綁在個別
## 場景腳本——HeaderBar 是唯一的倍速/暫停控制入口,同時掛在大地圖(map.gd)跟根據地
## (base.gd),只要場景掛了 HeaderBar,is_playing 為真時世界時間就會走,不會出現「按了
## 播放、圖示也變了,但時間沒在跑」的不一致(根據地過去沒有場景腳本呼叫 advance(),
## 只有大地圖的 map.gd._process() 會推進)。advance() 內部本來就會檢查 is_playing,
## 暫停時呼叫也不會動,這裡不用另外判斷。
func _process(delta: float) -> void:
	WorldTimeStore.controller.advance(delta * WorldTimeStore.play_speed_multiplier)
	_update_time_label()


## 圖示語意:⏸️ 暫停中;▶️ 播放中(1x/2x/3x);⏩ 播放中且倍速等級是 DEMO(4)。跟
## 倍速按鈕的 ▶️/⏩ 用同一套視覺語言。
func _update_time_label() -> void:
	var state_icon: String
	if not WorldTimeStore.controller.is_playing:
		state_icon = "⏸️"
	elif WorldTimeStore.speed_level == 2:
		state_icon = "⏩"
	elif WorldTimeStore.speed_level == 3:
		state_icon = "⏩"
	elif WorldTimeStore.speed_level == 4:
		state_icon = "⏩"
	else:
		state_icon = "▶️"
	time_label.text = "%s　%s" % [WorldTimeStore.get_display_string(), state_icon]


## Space 切換播放/暫停、1/2/3/4 切倍速等級——跟滑鼠點按鈕共用同一個 ButtonGroup +
## _on_speed_button_toggled(),數字鍵只是程式化按下對應按鈕,不另外開一條路徑改
## WorldTimeStore。這支 HeaderBar 是全域唯一的倍速/暫停控制入口,所在場景不需要自己
## 再接一份鍵盤快捷鍵。
func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_SPACE:
		WorldTimeStore.toggle_playing()
	elif _KEY_TO_SPEED_LEVEL.has(key_event.keycode):
		speed_buttons[_KEY_TO_SPEED_LEVEL[key_event.keycode]].set_pressed(true)


## 給需要在 HEADER 上多掛一顆下拉選單的場景用,塞在漢堡選單(☰)前面、倍速按鈕後面,
## 回傳的 MenuButton 由呼叫端自己用 get_popup() 填內容/接訊號——HeaderBar 本身不知道
## 內容是什麼,維持通用元件不綁特定場景的資料。
func add_menu_button(button_text: String) -> MenuButton:
	var button := MenuButton.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(64, 36)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_stylebox_override("normal", UiStyle.bordered_panel(_BUTTON_BG, _BUTTON_BORDER, 2, 8))
	button.add_theme_stylebox_override("hover", UiStyle.bordered_panel(_BUTTON_HOVER_BG, _BUTTON_HOVER_BORDER, 2, 8))
	button.add_theme_stylebox_override("pressed", UiStyle.bordered_panel(_BUTTON_PRESSED_BG, _BUTTON_BORDER, 2, 8))
	_row.add_child(button)
	_row.move_child(button, _row.get_child_count() - 2)
	return button


## 根據地資源(Scripts/Autoload/base_resource_store.gd)是全域狀態,不是只有
## Scenes/Base/base.gd 在乎——Scenes/Map/map.gd 也掛這顆,玩家在大地圖上也能隨時看
## 目前存量,不用特地跑一趟根據地。內容(GameEnums.ResourceType)屬於根據地系統的
## 概念,HeaderBar 直接知道怎麼畫這個下拉選單雖然不算完全跟場景資料無關,但比起
## 兩個場景各自複製貼上同一段清單重建邏輯更不容易漏改,跟下面 _on_menu_id_pressed()
## 直接呼叫 NavigationStore 是同一種「HeaderBar 內建幾個公用場景都會用到的功能」的
## 取捨。展開下拉選單時才重建內容,只列非 0 的資源。
func add_resource_menu_button() -> void:
	var button := add_menu_button("資源")
	button.get_popup().about_to_popup.connect(_refresh_resource_menu.bind(button))


func _refresh_resource_menu(button: MenuButton) -> void:
	var popup := button.get_popup()
	popup.clear()
	for resource_type in GameEnums.ResourceType.values():
		var amount := BaseResourceStore.get_amount(resource_type)
		if amount == 0:
			continue
		popup.add_item("%s %s %d" % [GameEnums.resource_type_label(resource_type), GameEnums.resource_string_label(resource_type), amount])
		popup.set_item_disabled(popup.item_count - 1, true)
	if popup.item_count == 0:
		popup.add_item("（尚無資源）")
		popup.set_item_disabled(0, true)


func _on_speed_button_toggled(enabled: bool, level: int) -> void:
	if enabled:
		WorldTimeStore.set_speed_level(level)


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
		_ID_MAIN_MENU:
			NavigationStore.go_to("res://Scenes/main.tscn")
