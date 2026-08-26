extends Control

# =========================================================
# 消息列表分「重大」/「日常」兩個分頁(GameEnums.NewsCategory),分頁樣式沿用
# nation_relations.gd 同一套 TabContainer stylebox 手法。每個分頁各自的表頭/捲動清單
# 都在 _build_category_tab() 裡用程式碼建構,不寫在 .tscn(比照 nation_relations.gd)。
#
# 未讀標示:NewsEntry.is_read 預設 false。_refresh_all() 在「標記已讀之前」先讀一次
# is_read 狀態決定要不要畫右側未讀圓點,再呼叫 NewsStore.mark_category_read() 把該分頁
# 目前所有消息標記已讀——本次畫面上的圓點維持顯示(已經畫出來的列不會消失),但下次重新
# 打開消息列表(或切到其他分頁又切回來)這批就不會再顯示未讀。分頁一開始只有分頁 0
# (重大)可見,所以只有它在 _ready() 當下立刻標記已讀;分頁 1(日常)要等玩家實際切過去
# (tab_changed)才標記,避免「根本沒點開日常分頁,裡面的消息卻已經算已讀」。
# =========================================================

const ROW_MIN_HEIGHT := 56.0
const TIME_COLUMN_STRETCH_RATIO := 2.0
const CONTENT_COLUMN_STRETCH_RATIO := 5.0
const UNREAD_DOT_SIZE := 10.0
const UNREAD_DOT_COLOR := Color(0.85, 0.25, 0.2, 1)

const CATEGORY_TITLES := {
	GameEnums.NewsCategory.MAJOR: "重大",
	GameEnums.NewsCategory.DAILY: "日常",
}

@onready var main_panel: PanelContainer = $MainPanel
@onready var vbox: VBoxContainer = $MainPanel/Margin/VBox
@onready var generate_button: Button = $TopBar/GenerateButton
@onready var back_button: Button = $TopBar/BackButton

var _tabs: TabContainer
## category (int) → { "list": VBoxContainer, "scroll": ScrollContainer }
var _category_lists: Dictionary = {}
## 分頁索引 → category,建分頁當下依序記錄,取代用分頁 name 字串反查分類。
var _category_order: Array[GameEnums.NewsCategory] = []


func _ready() -> void:
	for button in [generate_button, back_button]:
		UiStyle.apply_wood_plaque_button(button, 30.0, 10.0)
		button.add_theme_font_size_override("font_size", 16)
	UiStyle.apply_parchment_panel(main_panel, 1320.0, 740.0)

	_tabs = TabContainer.new()
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style_tabs(_tabs)
	vbox.add_child(_tabs)

	for category in [GameEnums.NewsCategory.MAJOR, GameEnums.NewsCategory.DAILY]:
		_tabs.add_child(_build_category_tab(category))
		_category_order.append(category)
	_tabs.tab_changed.connect(_on_tab_changed)

	_refresh_all()


## 分頁樣式沿用 nation_relations.gd/character_detail_view.gd 同一組羊皮紙配色。
func _style_tabs(tabs: TabContainer) -> void:
	tabs.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	tabs.add_theme_stylebox_override("tab_selected", UiStyle.bordered_panel(
		Color(0.85, 0.72, 0.5, 0.6), UiStyle.PARCHMENT_ROW_BORDER, 1, 8, 10.0, 6.0
	))
	tabs.add_theme_stylebox_override("tab_unselected", UiStyle.bordered_panel(
		Color(0.55, 0.42, 0.26, 0.12), Color(0, 0, 0, 0), 0, 8, 10.0, 6.0
	))
	tabs.add_theme_stylebox_override("tab_hovered", UiStyle.bordered_panel(
		Color(0.7, 0.55, 0.35, 0.35), UiStyle.PARCHMENT_ROW_BORDER, 1, 8, 10.0, 6.0
	))
	tabs.add_theme_color_override("font_selected_color", UiStyle.PARCHMENT_TEXT_COLOR)
	tabs.add_theme_color_override("font_unselected_color", UiStyle.PARCHMENT_SUBTITLE_COLOR)
	tabs.add_theme_color_override("font_hovered_color", UiStyle.PARCHMENT_TEXT_COLOR)


func _build_category_tab(category: GameEnums.NewsCategory) -> Control:
	var column := VBoxContainer.new()
	column.name = CATEGORY_TITLES[category]
	column.add_theme_constant_override("separation", 14)

	var header_row := MarginContainer.new()
	header_row.add_theme_constant_override("margin_left", 16)
	header_row.add_theme_constant_override("margin_right", 16)
	column.add_child(header_row)

	var header_content := HBoxContainer.new()
	header_content.add_theme_constant_override("separation", 20)
	header_row.add_child(header_content)

	header_content.add_child(_build_header_label("時間", TIME_COLUMN_STRETCH_RATIO))
	header_content.add_child(_build_header_label("系統時間", TIME_COLUMN_STRETCH_RATIO))
	header_content.add_child(_build_header_label("消息內容", CONTENT_COLUMN_STRETCH_RATIO))
	## 對齊每列右側的未讀圓點欄位(見 _spawn_news_row()),不然表頭三欄會比清單內容欄寬。
	var dot_spacer := Control.new()
	dot_spacer.custom_minimum_size = Vector2(UNREAD_DOT_SIZE, 0)
	header_content.add_child(dot_spacer)

	var scroll_container := ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UiStyle.apply_parchment_scrollbar(scroll_container)
	column.add_child(scroll_container)

	var news_list := VBoxContainer.new()
	news_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	news_list.add_theme_constant_override("separation", 10)
	scroll_container.add_child(news_list)

	_category_lists[category] = {"list": news_list, "scroll": scroll_container}
	return column


func _build_header_label(text: String, stretch_ratio: float) -> Label:
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_stretch_ratio = stretch_ratio
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", UiStyle.PARCHMENT_SUBTITLE_COLOR)
	return label


## 依序重建兩個分頁的清單:先讀 is_read 決定要不要畫未讀圓點,清單建完才標記目前
## _tabs.current_tab 那個分頁已讀,不能反過來——先標記的話畫出來的圓點會直接跟著消失。
## 只標記目前看得到的那個分頁,另一個分頁留給 _on_tab_changed() 在玩家真的切過去時才標記
## ——沒點開過的分頁不該悄悄被標成已讀。
func _refresh_all() -> void:
	for category in _category_lists:
		var refs: Dictionary = _category_lists[category]
		var list: VBoxContainer = refs["list"]
		for child in list.get_children():
			child.queue_free()

		var entries := _entries_for_category(category)
		entries.reverse()
		for entry in entries:
			list.add_child(_spawn_news_row(entry))

	NewsStore.mark_category_read(_category_order[_tabs.current_tab])


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


func _on_tab_changed(tab_index: int) -> void:
	NewsStore.mark_category_read(_category_order[tab_index])


func _on_generate_pressed() -> void:
	NewsController.post("測試消息：世界依然和平。", _category_order[_tabs.current_tab])
	_refresh_all()


func _on_back_pressed() -> void:
	NavigationStore.go_back()
