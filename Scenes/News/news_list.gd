extends Control

const ROW_MIN_HEIGHT := 56.0
const TIME_COLUMN_STRETCH_RATIO := 2.0
const CONTENT_COLUMN_STRETCH_RATIO := 5.0

const ROW_STYLE_BG := Color(0.13, 0.15, 0.21, 0.95)
const ROW_STYLE_BORDER := Color(0.36, 0.4, 0.56, 1)

@onready var news_list: VBoxContainer = $MainPanel/Margin/VBox/ScrollContainer/NewsList
@onready var generate_button: Button = $TopBar/GenerateButton
@onready var back_button: Button = $TopBar/BackButton


func _ready() -> void:
	for button in [generate_button, back_button]:
		UiStyle.apply_wood_plaque_button(button, 30.0, 10.0)
		button.add_theme_font_size_override("font_size", 16)
	_refresh_list()


func _refresh_list() -> void:
	for child in news_list.get_children():
		child.queue_free()
	var entries := NewsStore.entries.duplicate()
	entries.reverse()
	for entry in entries:
		_spawn_news_row(entry)


func _spawn_news_row(entry: NewsEntry) -> void:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, ROW_MIN_HEIGHT)

	row.add_theme_stylebox_override("panel", UiStyle.bordered_panel(
		ROW_STYLE_BG, ROW_STYLE_BORDER, 2, 8, 16.0, 6.0
	))

	var content_row := HBoxContainer.new()
	content_row.add_theme_constant_override("separation", 20)
	row.add_child(content_row)

	var game_time_label := Label.new()
	game_time_label.text = entry.game_time_text
	game_time_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game_time_label.size_flags_stretch_ratio = TIME_COLUMN_STRETCH_RATIO
	game_time_label.add_theme_font_size_override("font_size", 16)
	content_row.add_child(game_time_label)

	var system_time_label := Label.new()
	system_time_label.text = entry.system_time_text
	system_time_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	system_time_label.size_flags_stretch_ratio = TIME_COLUMN_STRETCH_RATIO
	system_time_label.add_theme_font_size_override("font_size", 16)
	system_time_label.add_theme_color_override("font_color", Color(0.75, 0.78, 0.88))
	content_row.add_child(system_time_label)

	var content_label := Label.new()
	content_label.text = entry.content
	content_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_label.size_flags_stretch_ratio = CONTENT_COLUMN_STRETCH_RATIO
	content_label.add_theme_font_size_override("font_size", 16)
	content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_row.add_child(content_label)

	news_list.add_child(row)


func _on_generate_pressed() -> void:
	NewsController.post("測試消息：世界依然和平。")
	_refresh_list()


func _on_back_pressed() -> void:
	NavigationStore.go_back()
