extends Control

# =========================================================
# 消息列表分「重大」/「日常」/「戰爭」三個分類(GameEnums.NewsCategory),左側 Sidebar
# 三顆互斥按鈕(見 news_list.tscn 共用的 ButtonGroup)切換,比照 Scenes/QuestList/quest_list.gd
# 左側分頁按鈕的做法——不用 TabContainer,主清單依 _current_category 篩選重建。
#
# 未讀標示:NewsEntry.is_read 預設 false。_refresh_list() 在「標記已讀之前」先讀一次
# is_read 狀態決定要不要畫右側未讀圓點,清單建完才呼叫 NewsStore.mark_category_read()
# 標記目前選中分類已讀——不能反過來,不然圓點畫出來當下就被自己清掉。切到另一個分類才會
# 標記那個分類已讀,沒點開過的分類不會被悄悄標成已讀。
# =========================================================

const ROW_MIN_HEIGHT := 56.0
const TIME_COLUMN_STRETCH_RATIO := 2.0
const CONTENT_COLUMN_STRETCH_RATIO := 5.0
const UNREAD_DOT_SIZE := 10.0
const UNREAD_DOT_COLOR := Color(0.85, 0.25, 0.2, 1)

@onready var main_panel: PanelContainer = $MainPanel
@onready var scroll_container: ScrollContainer = $MainPanel/Margin/VBox/ScrollContainer
@onready var news_list: VBoxContainer = $MainPanel/Margin/VBox/ScrollContainer/NewsList
@onready var generate_button: Button = $TopBar/GenerateButton
@onready var back_button: Button = $TopBar/BackButton
@onready var sidebar: PanelContainer = $Sidebar
@onready var major_button: Button = $Sidebar/Margin/VBox/MajorButton
@onready var daily_button: Button = $Sidebar/Margin/VBox/DailyButton
@onready var war_button: Button = $Sidebar/Margin/VBox/WarButton

## 目前選中的分類,預設「重大」,對應 news_list.tscn 的 MajorButton button_pressed = true。
var _current_category: GameEnums.NewsCategory = GameEnums.NewsCategory.MAJOR


func _ready() -> void:
	for button in [generate_button, back_button]:
		UiStyle.apply_wood_plaque_button(button, 30.0, 10.0)
		button.add_theme_font_size_override("font_size", 16)
	UiStyle.apply_parchment_panel(main_panel, 1100.0, 740.0)
	UiStyle.apply_parchment_scrollbar(scroll_container)
	UiStyle.apply_parchment_panel(sidebar, 200.0, 740.0)
	for button in [major_button, daily_button, war_button]:
		UiStyle.apply_wood_plaque_button(button, 20.0, 10.0)
		button.add_theme_font_size_override("font_size", 18)

	_refresh_list()


func _on_category_button_pressed(category: GameEnums.NewsCategory) -> void:
	_current_category = category
	_refresh_list()


## 先依 is_read 畫未讀圓點,清單建完才標記已讀——見檔頭註解。
func _refresh_list() -> void:
	for child in news_list.get_children():
		child.queue_free()

	var entries := _entries_for_category(_current_category)
	entries.reverse()
	for entry in entries:
		news_list.add_child(_spawn_news_row(entry))

	NewsStore.mark_category_read(_current_category)


func _entries_for_category(category: GameEnums.NewsCategory) -> Array:
	var result: Array = []
	for entry in NewsStore.entries:
		if entry.category == category:
			result.append(entry)
	return result


func _spawn_news_row(entry: NewsEntry) -> Control:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, ROW_MIN_HEIGHT)

	row.add_theme_stylebox_override("panel", UiStyle.parchment_row_style(
		UiStyle.PARCHMENT_ROW_BORDER, 2, 8, 16.0, 6.0
	))

	var content_row := HBoxContainer.new()
	content_row.add_theme_constant_override("separation", 20)
	row.add_child(content_row)

	var game_time_label := Label.new()
	game_time_label.text = entry.game_time_text
	game_time_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game_time_label.size_flags_stretch_ratio = TIME_COLUMN_STRETCH_RATIO
	game_time_label.add_theme_font_size_override("font_size", 16)
	game_time_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	content_row.add_child(game_time_label)

	var system_time_label := Label.new()
	system_time_label.text = entry.system_time_text
	system_time_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	system_time_label.size_flags_stretch_ratio = TIME_COLUMN_STRETCH_RATIO
	system_time_label.add_theme_font_size_override("font_size", 16)
	system_time_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_SUBTITLE_COLOR)
	content_row.add_child(system_time_label)

	var content_label := Label.new()
	content_label.text = entry.content
	content_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_label.size_flags_stretch_ratio = CONTENT_COLUMN_STRETCH_RATIO
	content_label.add_theme_font_size_override("font_size", 16)
	content_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_row.add_child(content_label)

	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(UNREAD_DOT_SIZE, UNREAD_DOT_SIZE)
	dot.color = UNREAD_DOT_COLOR
	dot.visible = not entry.is_read
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content_row.add_child(dot)

	return row


func _on_generate_pressed() -> void:
	NewsController.post("測試消息：世界依然和平。", _current_category)
	_refresh_list()


func _on_back_pressed() -> void:
	NavigationStore.go_back()
