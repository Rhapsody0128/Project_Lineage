class_name HeaderBar
extends Control

# =========================================================
# 大地圖等場景共用的頂部列:左側顯示目前世界時間(由外部呼叫 set_time_text()
# 更新,HeaderBar 本身不管時間怎麼算)、旁邊四顆倍速按鈕(1x/2x/3x/DEMO,互斥的
# 單選按鈕組,點下去觸發 speed_level_changed 訊號,HeaderBar 只負責按鈕外觀切換,
# 實際上要讓誰的時間/移動變快由呼叫端接訊號決定,見 Scenes/Map/map.gd——同一個
# 場景同時支援鍵盤 1/2/3/4 直接切等級),右上角一顆漢堡選單按鈕,點開下拉選單可
# 直接切去戰報列表/隊伍編輯/角色列表,或直接跳回主選單,不用像 main.gd 那樣得先
# 繞回主選單才能到這些畫面。切場景一律走 NavigationStore.go_to(),
# party_edit.gd/battle_report_list.gd/character_roster.gd 的返回鍵才能正確
# 回到這裡,而不是寫死回 Scenes/main.tscn。
#
# 跟 CharacterSortFilterBar 一樣是純程式碼組畫面的共用元件,用法:
# var header := HeaderBar.new(); some_canvas_layer.add_child(header)
# header.set_time_text(...) 更新時間顯示。
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
## ⏩ 代表快轉,跟 _update_date_label()(Scenes/Map/map.gd)裡播放中/暫停用的
## ▶️/⏸️ 圖示呼應,同一套視覺語言。
const _SPEED_LEVEL_LABELS := {1: "▶️ 1x", 2: "▶️ 2x", 3: "▶️ 3x", 4: "⏩ DEMO"}
const _SPEED_BUTTON_BG := Color(0.2, 0.24, 0.36, 1)
const _SPEED_BUTTON_ACTIVE_BG := Color(0.55, 0.32, 0.16, 1)

## 呼叫端(目前是 Scenes/Map/map.gd)接這個訊號決定要讓誰的時間/移動變快,HeaderBar
## 本身不知道倍速實際上要對誰生效(見 Scripts/Autoload/world_time_store.gd 的
## set_speed_level())。
signal speed_level_changed(level: int)

var time_label: Label
## 等級(1/2/3/4)→ 對應按鈕,單選按鈕組(ButtonGroup)確保同時間只有一顆按下。
var speed_buttons: Dictionary = {}


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

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	bg.add_child(row)

	time_label = Label.new()
	time_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	time_label.add_theme_font_size_override("font_size", 22)
	time_label.add_theme_color_override("font_color", _TIME_FONT_COLOR)
	time_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	time_label.add_theme_constant_override("outline_size", 4)
	row.add_child(time_label)

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
		row.add_child(speed_button)
		speed_buttons[level] = speed_button
	speed_buttons[1].set_pressed_no_signal(true)

	var menu_button := MenuButton.new()
	menu_button.text = "☰"
	menu_button.custom_minimum_size = Vector2(48, 36)
	menu_button.add_theme_font_size_override("font_size", 20)
	menu_button.add_theme_stylebox_override("normal", UiStyle.bordered_panel(_BUTTON_BG, _BUTTON_BORDER, 2, 8))
	menu_button.add_theme_stylebox_override("hover", UiStyle.bordered_panel(_BUTTON_HOVER_BG, _BUTTON_HOVER_BORDER, 2, 8))
	menu_button.add_theme_stylebox_override("pressed", UiStyle.bordered_panel(_BUTTON_PRESSED_BG, _BUTTON_BORDER, 2, 8))
	row.add_child(menu_button)

	var popup := menu_button.get_popup()
	popup.add_item("戰報", _ID_REPORTS)
	popup.add_item("隊伍", _ID_PARTY)
	popup.add_item("角色", _ID_CHARACTERS)
	popup.add_item("消息", _ID_NEWS)
	popup.add_item("主選單", _ID_MAIN_MENU)
	popup.id_pressed.connect(_on_menu_id_pressed)


func set_time_text(text: String) -> void:
	time_label.text = text


## 呼叫端在 _ready() 建立 HeaderBar 後,或鍵盤 1/2/3/4 切換等級後,用目前實際的
## 倍速等級(例如 WorldTimeStore.is_fast_forwarding 為真時傳 4,否則傳
## int(WorldTimeStore.play_speed_multiplier))同步按鈕外觀——倍速是全域狀態,離開/
## 返回場景不會重置,但每次都是全新的 HeaderBar 節點,按鈕預設停在 1x,需要呼叫端
## 主動同步一次,不然畫面看起來像沒在快轉,實際上時鐘還在背景跳。不觸發
## speed_level_changed(避免呼叫端自己觸發自己的 handler 造成迴圈)。
func set_speed_level(level: int) -> void:
	for button_level in speed_buttons.keys():
		speed_buttons[button_level].set_pressed_no_signal(button_level == level)


func _on_speed_button_toggled(enabled: bool, level: int) -> void:
	if enabled:
		speed_level_changed.emit(level)


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
