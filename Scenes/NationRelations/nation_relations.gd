extends Control

# =========================================================
# 國家關係:左側 Sidebar 兩顆互斥按鈕(見 nation_relations.tscn 共用的 ButtonGroup)切換
# 「友好度」/「邦交狀態」,比照 Scenes/QuestList/quest_list.gd 左側分頁按鈕的做法——不用
# TabContainer,MainPanel 內容依 _current_view 整包重建(_refresh_content())。
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
# NationFavorStore.changed 只在目前停留在「友好度」畫面時即時刷新那份清單,停留在
# 「邦交狀態」畫面時不動——切回「友好度」時 _refresh_content() 本來就會重建成最新資料。
# =========================================================

const VIEW_FAVOR := 0
const VIEW_WAR := 1

const FAVOR_TEST_AMOUNT := 10

const ROW_MIN_HEIGHT := 46.0
const NATION_COLUMN_WIDTH := 90.0
const RANK_COLUMN_WIDTH := 70.0
const VALUE_COLUMN_WIDTH := 120.0

const FAVOR_BAR_HEIGHT := 18.0
const FAVOR_BAR_BG := Color(0.25, 0.18, 0.1)

const MATRIX_CELL_SIZE := Vector2(84.0, 56.0)
const WAR_STATUS_COLORS := {
	GameEnums.NationWarStatus.PEACE: Color(0.1, 0.6, 0.1),
	GameEnums.NationWarStatus.WAR: Color(0.75, 0.1, 0.1),
}

@onready var main_panel: PanelContainer = $MainPanel
@onready var main_margin: MarginContainer = $MainPanel/Margin
@onready var test_favor_button: Button = $TopBar/TestFavorButton
@onready var back_button: Button = $TopBar/BackButton
@onready var sidebar: PanelContainer = $Sidebar
@onready var favor_button: Button = $Sidebar/Margin/VBox/FavorButton
@onready var war_button: Button = $Sidebar/Margin/VBox/WarButton

## 目前選中的畫面,預設「友好度」,對應 nation_relations.tscn 的 FavorButton button_pressed = true。
var _current_view: int = VIEW_FAVOR
## 只在 VIEW_FAVOR 畫面存在,VIEW_WAR 畫面時為 null——見 _on_favor_store_changed()。
var favor_list: VBoxContainer


func _ready() -> void:
	UiStyle.apply_parchment_panel(main_panel, 1132.0, 760.0)
	UiStyle.apply_wood_plaque_button(test_favor_button, 20.0, 10.0)
	test_favor_button.add_theme_font_size_override("font_size", 16)
	UiStyle.apply_wood_plaque_button(back_button, 30.0, 10.0)
	back_button.add_theme_font_size_override("font_size", 16)
	UiStyle.apply_parchment_panel(sidebar, 200.0, 760.0)
	for button in [favor_button, war_button]:
		UiStyle.apply_wood_plaque_button(button, 20.0, 10.0)
		button.add_theme_font_size_override("font_size", 18)

	NationFavorStore.changed.connect(_on_favor_store_changed)
	_refresh_content()


func _on_view_button_pressed(view: int) -> void:
	_current_view = view
	_refresh_content()


func _refresh_content() -> void:
	for child in main_margin.get_children():
		child.queue_free()
	favor_list = null

	if _current_view == VIEW_FAVOR:
		main_margin.add_child(_build_favor_view())
	else:
		main_margin.add_child(_build_war_view())


func _on_favor_store_changed() -> void:
	if _current_view == VIEW_FAVOR:
		_refresh_favor_list()


func _build_favor_view() -> Control:
	var column := VBoxContainer.new()
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

	_refresh_favor_list()
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


func _build_war_view() -> Control:
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL

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
	var tension := NationRelation.get_tension(nation_a, nation_b)
	var cell := _build_matrix_blank_cell()

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER

	var status_label := Label.new()
	status_label.text = GameEnums.nation_war_status_label(status)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", WAR_STATUS_COLORS[status])
	column.add_child(status_label)

	# 張力數字從白漸層到紅,不用等真的宣戰才看得出兩國關係正在惡化。
	var tension_label := Label.new()
	tension_label.text = "%.0f" % tension
	tension_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tension_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tension_label.add_theme_font_size_override("font_size", 12)
	tension_label.add_theme_color_override("font_color", Color.WHITE.lerp(Color(0.75, 0.1, 0.1), tension / 100.0))
	column.add_child(tension_label)

	cell.add_child(column)
	return cell


func _on_test_favor_pressed() -> void:
	for nation_id in GameEnums.BloodlineNation.values():
		NationFavorStore.add_favor(nation_id, FAVOR_TEST_AMOUNT)


func _on_back_pressed() -> void:
	NavigationStore.go_back()
