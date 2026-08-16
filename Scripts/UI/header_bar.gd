class_name HeaderBar
extends Control

# =========================================================
# 大地圖等場景共用的頂部列:左側顯示目前世界時間(由外部呼叫 set_time_text()
# 更新,HeaderBar 本身不管時間怎麼算)、旁邊一顆超快速流逝時間切換按鈕(按下去
# 觸發 fast_forward_toggled 訊號,HeaderBar 只負責按鈕外觀切換,實際上要讓誰的
# 時間快轉由呼叫端接訊號決定,見 Scenes/Map/map.gd),右上角一顆漢堡選單按鈕,
# 點開下拉選單可直接切去戰報列表/隊伍編輯/角色列表,或直接跳回主選單,不用像
# main.gd 那樣得先繞回主選單才能到這些畫面。切場景一律走 NavigationStore.go_to(),
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

const _FAST_FORWARD_TEXT := "⏩ 快轉"
const _FAST_FORWARD_ACTIVE_TEXT := "⏹ 停止快轉"
const _FAST_FORWARD_BG := Color(0.2, 0.24, 0.36, 1)
const _FAST_FORWARD_ACTIVE_BG := Color(0.55, 0.32, 0.16, 1)

## 呼叫端(目前是 Scenes/Map/map.gd)接這個訊號決定要不要開始/停止快轉,HeaderBar
## 本身不知道快轉實際上要對誰生效(見 Scripts/Autoload/world_time_store.gd 的
## toggle_fast_forward())。
signal fast_forward_toggled(enabled: bool)

var time_label: Label
var fast_forward_button: Button


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

	fast_forward_button = Button.new()
	fast_forward_button.text = _FAST_FORWARD_TEXT
	fast_forward_button.toggle_mode = true
	fast_forward_button.custom_minimum_size = Vector2(110, 36)
	fast_forward_button.add_theme_font_size_override("font_size", 18)
	fast_forward_button.add_theme_stylebox_override("normal", UiStyle.bordered_panel(_FAST_FORWARD_BG, _BUTTON_BORDER, 2, 8))
	fast_forward_button.add_theme_stylebox_override("hover", UiStyle.bordered_panel(_BUTTON_HOVER_BG, _BUTTON_HOVER_BORDER, 2, 8))
	fast_forward_button.add_theme_stylebox_override("pressed", UiStyle.bordered_panel(_FAST_FORWARD_ACTIVE_BG, _BUTTON_HOVER_BORDER, 2, 8))
	fast_forward_button.toggled.connect(_on_fast_forward_button_toggled)
	row.add_child(fast_forward_button)

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


## 呼叫端在 _ready() 建立 HeaderBar 後,用目前實際的快轉狀態(例如
## WorldTimeStore.is_fast_forwarding)同步按鈕外觀——快轉是全域狀態,離開/返回
## 場景不會重置,但每次都是全新的 HeaderBar 節點,按鈕預設是未按下,需要呼叫端
## 主動同步一次,不然畫面看起來像沒在快轉,實際上時鐘還在背景跳。不觸發
## fast_forward_toggled(避免呼叫端自己觸發自己的 handler 造成迴圈)。
func set_fast_forwarding(enabled: bool) -> void:
	fast_forward_button.set_pressed_no_signal(enabled)
	fast_forward_button.text = _FAST_FORWARD_ACTIVE_TEXT if enabled else _FAST_FORWARD_TEXT


func _on_fast_forward_button_toggled(enabled: bool) -> void:
	fast_forward_button.text = _FAST_FORWARD_ACTIVE_TEXT if enabled else _FAST_FORWARD_TEXT
	fast_forward_toggled.emit(enabled)


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
