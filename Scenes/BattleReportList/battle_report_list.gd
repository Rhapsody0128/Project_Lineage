extends Control

# =========================================================
# 戰報列表:表格呈現 BattleReportStore 裡所有戰報(含 2 筆 DEMO 戰報),欄位為
# 「遊戲時間 / 系統時間 / 觀戰 / 戰報」——觀戰進 Battle 場景重播戰鬥畫面,戰報進
# BattleReportStats 場景看這場戰鬥的統計數字。「生成隨機戰報」按鈕呼叫
# BattleController.generate_random_report() 現跑一場、記錄進列表。
#
# 清單項目跟 battle_party_roster.gd 一樣,整排用程式碼動態產生,不另外開 row 用的
# 子場景;欄寬用 size_flags_stretch_ratio 對齊靜態表頭(HeaderRow)的比例。
# =========================================================

const ROW_MIN_HEIGHT := 56.0
const TIME_COLUMN_STRETCH_RATIO := 3.0
const ACTION_COLUMN_WIDTH := 90.0

const WIN_COLOR := Color(0.55, 0.85, 0.55)
const LOSE_COLOR := Color(0.9, 0.5, 0.5)
const DRAW_COLOR := Color(0.85, 0.8, 0.6)

@onready var main_panel: PanelContainer = $MainPanel
@onready var scroll_container: ScrollContainer = $MainPanel/Margin/VBox/ScrollContainer
@onready var report_list: VBoxContainer = $MainPanel/Margin/VBox/ScrollContainer/ReportList
@onready var generate_button: Button = $TopBar/GenerateButton
@onready var back_button: Button = $TopBar/BackButton


func _ready() -> void:
	for button in [generate_button, back_button]:
		UiStyle.apply_wood_plaque_button(button, 30.0, 10.0)
		button.add_theme_font_size_override("font_size", 16)
	UiStyle.apply_parchment_panel(main_panel, 1320.0, 740.0)
	UiStyle.apply_parchment_scrollbar(scroll_container)
	_refresh_list()


func _refresh_list() -> void:
	for child in report_list.get_children():
		child.queue_free()
	var reports := BattleReportStore.reports.duplicate()
	reports.reverse()
	for report in reports:
		_spawn_report_row(report)


func _spawn_report_row(report: BattleReport) -> void:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, ROW_MIN_HEIGHT)

	row.add_theme_stylebox_override("panel", UiStyle.parchment_row_style(
		UiStyle.PARCHMENT_ROW_BORDER, 2, 8, 16.0, 6.0
	))

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 20)
	row.add_child(content)

	var game_time_label := Label.new()
	game_time_label.text = report.title
	game_time_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game_time_label.size_flags_stretch_ratio = TIME_COLUMN_STRETCH_RATIO
	game_time_label.add_theme_font_size_override("font_size", 16)
	game_time_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	content.add_child(game_time_label)

	var system_time_label := Label.new()
	system_time_label.text = report.system_time_text
	system_time_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	system_time_label.size_flags_stretch_ratio = TIME_COLUMN_STRETCH_RATIO
	system_time_label.add_theme_font_size_override("font_size", 16)
	system_time_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_SUBTITLE_COLOR)
	content.add_child(system_time_label)

	var result_label := Label.new()
	result_label.text = report.result_text
	result_label.custom_minimum_size = Vector2(ACTION_COLUMN_WIDTH, 0)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 15)
	result_label.add_theme_color_override("font_color", _result_color(report))
	content.add_child(result_label)

	var watch_button := Button.new()
	watch_button.text = "觀戰"
	watch_button.custom_minimum_size = Vector2(ACTION_COLUMN_WIDTH, 0)
	watch_button.pressed.connect(_on_watch_pressed.bind(report))
	UiStyle.apply_wood_plaque_button(watch_button, 14.0, 8.0)
	watch_button.add_theme_font_size_override("font_size", 15)
	content.add_child(watch_button)

	var stats_button := Button.new()
	stats_button.text = "戰報"
	stats_button.custom_minimum_size = Vector2(ACTION_COLUMN_WIDTH, 0)
	stats_button.pressed.connect(_on_stats_pressed.bind(report))
	UiStyle.apply_wood_plaque_button(stats_button, 14.0, 8.0)
	stats_button.add_theme_font_size_override("font_size", 15)
	content.add_child(stats_button)

	report_list.add_child(row)


func _result_color(report: BattleReport) -> Color:
	match report.result:
		GameEnums.BattleResultType.SELF_WIN:
			return WIN_COLOR
		GameEnums.BattleResultType.ENEMY_WIN:
			return LOSE_COLOR
		_:
			return DRAW_COLOR


func _on_watch_pressed(report: BattleReport) -> void:
	BattleReportStore.queue_playback(report)
	NavigationStore.go_to("res://Scenes/Battle/battle.tscn")


func _on_stats_pressed(report: BattleReport) -> void:
	BattleReportStore.queue_stats(report)
	NavigationStore.go_to("res://Scenes/BattleReportStats/battle_report_stats.tscn")


func _on_generate_pressed() -> void:
	BattleReportStore.generate_demo_report()
	_refresh_list()


func _on_back_pressed() -> void:
	NavigationStore.go_back()
