extends Control

# =========================================================
# 戰報列表:左側 Sidebar 兩顆互斥按鈕(見 battle_report_list.tscn 共用的 ButtonGroup,
# 比照 Scenes/QuestList/quest_list.gd 左側分頁按鈕的做法)切換「一般戰鬥」/「戰爭戰報」。
#
# 「一般戰鬥」表格呈現 BattleReportStore.reports 裡所有戰報(含 2 筆 DEMO 戰報),欄位為
# 「描述 / 遊戲時間 / 系統時間 / 觀戰 / 戰報」——描述預設依敵方 rank_type 自動生成
# 「O級敵人遭遇戰」(見 BattleReport.description);觀戰進 Battle 場景重播戰鬥畫面,戰報進
# BattleReportStats 場景看這場戰鬥的統計數字。「生成隨機戰報」按鈕呼叫
# BattleController.generate_random_report() 現跑一場、記錄進列表。
#
# 「戰爭戰報」表格呈現 BattleReportStore.war_campaign_reports(WarBattleEvent 連續作戰打完
# 的結果集合,見 System/war/war_campaign_controller.gd),欄位為「描述(O VS O 戰場戰報)/
# 遊戲時間 / 系統時間 / 戰績 / 展開」——手風琴模式:按「展開」在同一個清單裡往下 append 出
# 這一輪每一場戰鬥,長得跟「一般戰鬥」分類一樣(觀戰/戰報按鈕都在,直接重用
# _spawn_report_row(),子項描述欄顯示的是「第 N 場」),不切場景到另一個專屬畫面。展開狀態
# 存在 _expanded_war_report_ids,按「收合」清掉子項。
#
# 清單項目跟 battle_party_roster.gd 一樣,整排用程式碼動態產生,不另外開 row 用的
# 子場景;欄寬用 size_flags_stretch_ratio 對齊靜態表頭(HeaderRow)的比例。
# =========================================================

const CATEGORY_NORMAL := 0
const CATEGORY_WAR := 1

const ROW_MIN_HEIGHT := 56.0
const TIME_COLUMN_STRETCH_RATIO := 3.0
const DESCRIPTION_COLUMN_STRETCH_RATIO := 2.5
const ACTION_COLUMN_WIDTH := 90.0

const WIN_COLOR := Color(0.15, 0.5, 0.15)
const LOSE_COLOR := Color(0.9, 0.1, 0.1)
const DRAW_COLOR := Color(0.0, 0.0, 0.0)

@onready var main_panel: PanelContainer = $MainPanel
@onready var scroll_container: ScrollContainer = $MainPanel/Margin/VBox/ScrollContainer
@onready var report_list: VBoxContainer = $MainPanel/Margin/VBox/ScrollContainer/ReportList
@onready var generate_button: Button = $TopBar/GenerateButton
@onready var back_button: Button = $TopBar/BackButton
@onready var sidebar: PanelContainer = $Sidebar
@onready var normal_battle_button: Button = $Sidebar/Margin/VBox/NormalBattleButton
@onready var war_report_button: Button = $Sidebar/Margin/VBox/WarReportButton

## 目前選中的分頁/展開中的戰爭戰報,離開這個場景(觀戰/看戰報統計)前都同步寫回
## BattleReportStore.list_last_category/list_expanded_war_report_ids,回到這個場景時
## _ready() 從那裡讀回來還原,不是每次重建節點就重置成預設值,見該處欄位註解。
var _current_category: int = CATEGORY_NORMAL

## 目前展開中的戰爭戰報(WarCampaignReport.id -> true),見 _spawn_war_campaign_row()。
var _expanded_war_report_ids: Dictionary = {}


func _ready() -> void:
	for button in [generate_button, back_button]:
		UiStyle.apply_wood_plaque_button(button, 30.0, 10.0)
		button.add_theme_font_size_override("font_size", 16)
	UiStyle.apply_parchment_panel(main_panel, 1100.0, 740.0)
	UiStyle.apply_parchment_scrollbar(scroll_container)
	UiStyle.apply_parchment_panel(sidebar, 200.0, 740.0)
	for button in [normal_battle_button, war_report_button]:
		UiStyle.apply_wood_plaque_button(button, 20.0, 10.0)
		button.add_theme_font_size_override("font_size", 18)

	_current_category = BattleReportStore.list_last_category
	_expanded_war_report_ids = BattleReportStore.list_expanded_war_report_ids.duplicate()
	normal_battle_button.set_pressed_no_signal(_current_category == CATEGORY_NORMAL)
	war_report_button.set_pressed_no_signal(_current_category == CATEGORY_WAR)
	_refresh_list()


func _on_category_button_pressed(category: int) -> void:
	_current_category = category
	BattleReportStore.list_last_category = category
	_refresh_list()


func _refresh_list() -> void:
	for child in report_list.get_children():
		child.queue_free()
	if _current_category == CATEGORY_WAR:
		var campaign_reports := BattleReportStore.war_campaign_reports.duplicate()
		campaign_reports.reverse()
		for report in campaign_reports:
			report_list.add_child(_spawn_war_campaign_row(report))
			if _expanded_war_report_ids.has(report.id):
				for fight_report in report.fight_reports:
					report_list.add_child(_wrap_indented(_spawn_report_row(fight_report)))
		return

	var reports := BattleReportStore.reports.duplicate()
	reports.reverse()
	for report in reports:
		report_list.add_child(_spawn_report_row(report))


func _spawn_report_row(report: BattleReport) -> Control:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, ROW_MIN_HEIGHT)

	row.add_theme_stylebox_override("panel", UiStyle.parchment_row_style(
		UiStyle.PARCHMENT_ROW_BORDER, 2, 8, 16.0, 6.0
	))

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 20)
	row.add_child(content)

	var description_label := Label.new()
	description_label.text = report.description
	description_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description_label.size_flags_stretch_ratio = DESCRIPTION_COLUMN_STRETCH_RATIO
	description_label.add_theme_font_size_override("font_size", 16)
	description_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_SUBTITLE_COLOR)
	content.add_child(description_label)

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

	return row


func _spawn_war_campaign_row(report: WarCampaignReport) -> Control:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, ROW_MIN_HEIGHT)

	row.add_theme_stylebox_override("panel", UiStyle.parchment_row_style(
		UiStyle.PARCHMENT_ROW_BORDER, 2, 8, 16.0, 6.0
	))

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 20)
	row.add_child(content)

	var description_label := Label.new()
	description_label.text = report.title
	description_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description_label.size_flags_stretch_ratio = DESCRIPTION_COLUMN_STRETCH_RATIO
	description_label.add_theme_font_size_override("font_size", 16)
	description_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_SUBTITLE_COLOR)
	content.add_child(description_label)

	var game_time_label := Label.new()
	game_time_label.text = report.game_time_text
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

	# 寬度對齊表頭 ResultHeader(90),不再用 1.5 倍寬——這一列只有一顆切換鈕(沒有「觀戰」),
	# 少掉的那個欄位改用下面的空白 Control 補上,不然這顆按鈕會偏移、跟表頭對不齊。
	var result_label := Label.new()
	result_label.text = report.result_summary_text
	result_label.custom_minimum_size = Vector2(ACTION_COLUMN_WIDTH, 0)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 15)
	result_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	content.add_child(result_label)

	var watch_column_spacer := Control.new()
	watch_column_spacer.custom_minimum_size = Vector2(ACTION_COLUMN_WIDTH, 0)
	content.add_child(watch_column_spacer)

	var expanded := _expanded_war_report_ids.has(report.id)
	var toggle_button := Button.new()
	toggle_button.text = "收合" if expanded else "展開"
	toggle_button.custom_minimum_size = Vector2(ACTION_COLUMN_WIDTH, 0)
	toggle_button.pressed.connect(_on_war_report_toggle_pressed.bind(report))
	UiStyle.apply_wood_plaque_button(toggle_button, 14.0, 8.0)
	toggle_button.add_theme_font_size_override("font_size", 15)
	content.add_child(toggle_button)

	return row


## 展開後直接內嵌一份跟「一般戰鬥」分類一樣的列(_spawn_report_row()),用左邊距表達
## 「這是展開出來的子項」,不切場景到另一個專屬詳情畫面。
func _wrap_indented(control: Control) -> Control:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_child(control)
	return margin


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


func _on_war_report_toggle_pressed(report: WarCampaignReport) -> void:
	if _expanded_war_report_ids.has(report.id):
		_expanded_war_report_ids.erase(report.id)
	else:
		_expanded_war_report_ids[report.id] = true
	BattleReportStore.list_expanded_war_report_ids = _expanded_war_report_ids.duplicate()
	_refresh_list()


func _on_generate_pressed() -> void:
	BattleReportStore.generate_demo_report()
	_refresh_list()


func _on_back_pressed() -> void:
	NavigationStore.go_back()
