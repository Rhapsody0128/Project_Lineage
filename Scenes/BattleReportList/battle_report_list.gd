extends Control

# =========================================================
# 戰報列表:列出 BattleReportStore 裡所有戰報(含 2 筆 DEMO 戰報),
# 每筆可按「播放」進 Battle 場景重播;「生成隨機戰報」按鈕呼叫
# BattleController.generate_random_report() 現跑一場、記錄進列表。
#
# 清單項目跟 battle_party_roster.gd 一樣,整排用程式碼動態產生,
# 不另外開 row 用的子場景。
# =========================================================

const ROW_MIN_HEIGHT := 56.0

const ROW_STYLE_BG := Color(0.13, 0.15, 0.21, 0.95)
const ROW_STYLE_BORDER := Color(0.36, 0.4, 0.56, 1)
const WIN_COLOR := Color(0.55, 0.85, 0.55)
const LOSE_COLOR := Color(0.9, 0.5, 0.5)
const DRAW_COLOR := Color(0.85, 0.8, 0.6)

@onready var report_list: VBoxContainer = $MainPanel/Margin/VBox/ScrollContainer/ReportList
@onready var generate_button: Button = $MainPanel/Margin/VBox/BottomBar/GenerateButton
@onready var back_button: Button = $MainPanel/Margin/VBox/BottomBar/BackButton


func _ready() -> void:
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

	row.add_theme_stylebox_override("panel", UiStyle.bordered_panel(
		ROW_STYLE_BG, ROW_STYLE_BORDER, 2, 8, 16.0, 6.0
	))

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 20)
	row.add_child(content)

	var title_label := Label.new()
	title_label.text = report.title
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 18)
	content.add_child(title_label)

	var result_label := Label.new()
	result_label.text = report.result_text
	result_label.add_theme_font_size_override("font_size", 15)
	result_label.add_theme_color_override("font_color", _result_color(report))
	content.add_child(result_label)

	var play_button := Button.new()
	play_button.text = "播放"
	play_button.custom_minimum_size = Vector2(90, 0)
	play_button.pressed.connect(_on_play_pressed.bind(report))
	content.add_child(play_button)

	report_list.add_child(row)


func _result_color(report: BattleReport) -> Color:
	match report.result:
		GameEnums.BattleResultType.SELF_WIN:
			return WIN_COLOR
		GameEnums.BattleResultType.ENEMY_WIN:
			return LOSE_COLOR
		_:
			return DRAW_COLOR


func _on_play_pressed(report: BattleReport) -> void:
	BattleReportStore.queue_playback(report)
	NavigationStore.go_to("res://Scenes/Battle/battle.tscn")


func _on_generate_pressed() -> void:
	BattleReportStore.generate_demo_report()
	_refresh_list()


func _on_back_pressed() -> void:
	NavigationStore.go_back()
