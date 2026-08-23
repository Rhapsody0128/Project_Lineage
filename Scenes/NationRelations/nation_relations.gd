extends Control

# =========================================================
# 國家關係:TabContainer 切「友好度」/「邦交狀態」兩分頁(比照
# Scenes/CharacterPanel/character_detail_view.gd 的 TabContainer 樣式,同一組
# tab_selected/tab_unselected/tab_hovered stylebox 配色)。
#
# 「友好度」列出六國對玩家的好感度(NationFavorStore)換算成 GameEnums.RankType 等級,
# 進度條顯示「本階段進度/本階段全距」(比照角色 EXP 進度條的呈現方式,不是總好感度/
# 總滿值)——例如 F 級門檻是 0~10,好感度 5 顯示「5/10」;E 級門檻是 10~50,好感度 17
# 顯示「7/40」。已到最高級(SSS,無下一級門檻)顯示「已達上限」,不會除以 0。
#
# 「邦交狀態」是六國兩兩之間戰爭情況的矩陣(System/nation/nation_relation.gd,目前尚無
# 機制會改變邦交,一律停戰)。
#
# TopBar 測試按鈕一次把六國好感度全部 +10,方便不用真的打贏戰鬥就能測試等級/進度條變化。
# =========================================================

const FAVOR_TEST_AMOUNT := 10

const ROW_MIN_HEIGHT := 46.0
const NATION_COLUMN_WIDTH := 90.0
const RANK_COLUMN_WIDTH := 70.0
const VALUE_COLUMN_WIDTH := 120.0

const FAVOR_BAR_HEIGHT := 18.0
const FAVOR_BAR_BG := Color(0.25, 0.18, 0.1)

const MATRIX_CELL_SIZE := Vector2(84.0, 44.0)
const WAR_STATUS_COLORS := {
	GameEnums.NationWarStatus.PEACE: Color(0.1, 0.6, 0.1),
	GameEnums.NationWarStatus.WAR: Color(0.75, 0.1, 0.1),
}

@onready var main_panel: PanelContainer = $MainPanel
@onready var main_margin: MarginContainer = $MainPanel/Margin
@onready var test_favor_button: Button = $TopBar/TestFavorButton
@onready var back_button: Button = $TopBar/BackButton

var favor_list: VBoxContainer


func _ready() -> void:
	UiStyle.apply_parchment_panel(main_panel, 1352.0, 760.0)
	UiStyle.apply_wood_plaque_button(test_favor_button, 20.0, 10.0)
	test_favor_button.add_theme_font_size_override("font_size", 16)
	UiStyle.apply_wood_plaque_button(back_button, 30.0, 10.0)
	back_button.add_theme_font_size_override("font_size", 16)

	var tabs := TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style_tabs(tabs)
	main_margin.add_child(tabs)

	tabs.add_child(_build_favor_tab())
	tabs.add_child(_build_war_tab())

	NationFavorStore.changed.connect(_refresh_favor_list)
	_refresh_favor_list()


## 分頁樣式沿用 character_detail_view.gd 同一組羊皮紙配色,兩處分頁視覺要一致。
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


func _build_favor_tab() -> Control:
	var column := VBoxContainer.new()
	column.name = "友好度"
	column.add_theme_constant_override("separation", 10)

	var header_row := MarginContainer.new()
	header_row.add_theme_constant_override("margin_left", 16)
	header_row.add_theme_constant_override("margin_right", 16)
	column.add_child(header_row)

	var header_content := HBoxContainer.new()
	header_content.add_theme_constant_override("separation", 20)
	header_row.add_child(header_content)

	header_content.add_child(_build_header_label("國家", NATION_COLUMN_WIDTH))
	header_content.add_child(_build_header_label("等級", RANK_COLUMN_WIDTH))
	var favor_header := _build_header_label("友好度", 0)
	favor_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_content.add_child(favor_header)
	header_content.add_child(_build_header_label("進度", VALUE_COLUMN_WIDTH))

	favor_list = VBoxContainer.new()
	favor_list.add_theme_constant_override("separation", 8)
	column.add_child(favor_list)

	return column


func _build_header_label(text: String, min_width: float) -> Label:
	var label := Label.new()
	label.text = text
	if min_width > 0.0:
		label.custom_minimum_size = Vector2(min_width, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", UiStyle.PARCHMENT_SUBTITLE_COLOR)
	return label


func _refresh_favor_list() -> void:
	for child in favor_list.get_children():
		child.queue_free()
	for nation in NationLibrary.get_all():
		favor_list.add_child(_build_favor_row(nation))


func _build_favor_row(nation: Nation) -> Control:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, ROW_MIN_HEIGHT)
	row.add_theme_stylebox_override("panel", UiStyle.parchment_row_style(
		UiStyle.PARCHMENT_ROW_BORDER, 2, 8, 16.0, 6.0
	))

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 20)
	row.add_child(content)

	var favor := NationFavorStore.get_favor(nation.id)
	var stage := _favor_stage_progress(favor)

	var nation_label := Label.new()
	nation_label.text = nation.name
	nation_label.custom_minimum_size = Vector2(NATION_COLUMN_WIDTH, 0)
	nation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nation_label.add_theme_font_size_override("font_size", 16)
	nation_label.add_theme_color_override("font_color", GameEnums.bloodline_nation_color(nation.id))
	content.add_child(nation_label)

	var rank_label := Label.new()
	rank_label.text = NationFavorRank.label_for_favor(favor)
	rank_label.custom_minimum_size = Vector2(RANK_COLUMN_WIDTH, 0)
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_label.add_theme_font_size_override("font_size", 15)
	rank_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	content.add_child(rank_label)

	var bar := _build_favor_bar(nation.id, stage)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(bar)

	var value_label := Label.new()
	value_label.text = stage["text"]
	value_label.custom_minimum_size = Vector2(VALUE_COLUMN_WIDTH, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", 15)
	value_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_SUBTITLE_COLOR)
	content.add_child(value_label)

	return row


## 「本階段進度/本階段全距」而非「總好感度/總滿值」——例如 F 級門檻 0~10,好感度 5
## 顯示「5/10」;E 級門檻 10~50,好感度 17 顯示「7/40」。已在最高級(SSS)沒有下一級
## 門檻可算全距,顯示「已達上限」,進度條畫滿。
func _favor_stage_progress(favor: int) -> Dictionary:
	var rank := NationFavorRank.rank_for_favor(favor)
	var lower: int = NationFavorRank.THRESHOLDS[rank]
	if rank >= NationFavorRank.THRESHOLDS.size() - 1:
		return {"progress": 1.0, "span": 1.0, "text": "已達上限"}
	var upper: int = NationFavorRank.THRESHOLDS[rank + 1]
	var progress := favor - lower
	var span := upper - lower
	return {"progress": float(progress), "span": float(span), "text": "%d/%d" % [progress, span]}


func _build_favor_bar(nation_id: int, stage: Dictionary) -> Control:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, FAVOR_BAR_HEIGHT)
	bar.show_percentage = false
	bar.max_value = stage["span"]
	bar.value = stage["progress"]

	var fill := StyleBoxFlat.new()
	fill.bg_color = GameEnums.bloodline_nation_color(nation_id)
	fill.set_corner_radius_all(int(FAVOR_BAR_HEIGHT / 2.0))
	bar.add_theme_stylebox_override("fill", fill)

	var bg := StyleBoxFlat.new()
	bg.bg_color = FAVOR_BAR_BG
	bg.set_corner_radius_all(int(FAVOR_BAR_HEIGHT / 2.0))
	bar.add_theme_stylebox_override("background", bg)

	return bar


func _build_war_tab() -> Control:
	var center := CenterContainer.new()
	center.name = "邦交狀態"

	var nations := NationLibrary.get_all()
	var grid := GridContainer.new()
	grid.columns = nations.size() + 1
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)

	grid.add_child(_build_matrix_blank_cell())
	for column_nation in nations:
		grid.add_child(_build_matrix_header_cell(column_nation))

	for row_nation in nations:
		grid.add_child(_build_matrix_header_cell(row_nation))
		for column_nation in nations:
			if row_nation.id == column_nation.id:
				grid.add_child(_build_matrix_blank_cell())
			else:
				grid.add_child(_build_matrix_status_cell(row_nation.id, column_nation.id))

	center.add_child(grid)
	return center


func _build_matrix_blank_cell() -> Control:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = MATRIX_CELL_SIZE
	cell.add_theme_stylebox_override("panel", UiStyle.parchment_row_style())
	return cell


func _build_matrix_header_cell(nation: Nation) -> Control:
	var cell := _build_matrix_blank_cell()
	var label := Label.new()
	label.text = nation.name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", GameEnums.bloodline_nation_color(nation.id))
	cell.add_child(label)
	return cell


func _build_matrix_status_cell(nation_a: int, nation_b: int) -> Control:
	var status := NationRelation.get_status(nation_a, nation_b)
	var cell := _build_matrix_blank_cell()
	var label := Label.new()
	label.text = GameEnums.nation_war_status_label(status)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", WAR_STATUS_COLORS[status])
	cell.add_child(label)
	return cell


func _on_test_favor_pressed() -> void:
	for nation_id in GameEnums.BloodlineNation.values():
		NationFavorStore.add_favor(nation_id, FAVOR_TEST_AMOUNT)


func _on_back_pressed() -> void:
	NavigationStore.go_back()
