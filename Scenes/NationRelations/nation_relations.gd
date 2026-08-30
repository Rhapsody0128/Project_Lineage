extends Control

# =========================================================
# 國家關係:左側 Sidebar 兩顆互斥按鈕(見 nation_relations.tscn 共用的 ButtonGroup)切換
# 「友好度」/「邦交狀態」,比照 Scenes/QuestList/quest_list.gd 左側分頁按鈕的做法——不用
# TabContainer,MainPanel 內容依 _current_view 整包重建(_refresh_content())。
#
# 「友好度」是「國旗欄 x 友好等級/友好度/進度列」的表格,不是逐國一列的清單——國旗當欄位
# 表頭(見 _build_nation_header_cell()),下面三列分別是等級/原始數值/本階段進度條,一次
# 六國並排方便互相比較。進度顯示「本階段進度/本階段全距」(比照角色 EXP 進度條的呈現
# 方式,不是總好感度/總滿值)——例如 F 級門檻是 0~10,好感度 5 顯示「5/10」;E 級門檻是
# 10~50,好感度 17 顯示「7/40」。已到最高級(SSS,無下一級門檻)顯示「已達上限」,不會
# 除以 0。
#
# 「邦交狀態」一次只看一個國家跟其他五國的關係,不是六國兩兩全展開的大矩陣(那樣資訊量
# 太大且大部分格子玩家用不到)。最上排是六國國旗(TextureButton + ButtonGroup 互斥切換,
# 寫法比照 stronghold_marriage_panel.gd 寄信國家按鈕),點哪個就以哪國為主角
# (_selected_war_nation),下方表格欄位排除自己、只列其餘五國,列分別是狀態/衝突值
# (WarTension,百分比)/疲憊值(War.war_exhaustion,只在雙方真的交戰中才有非 0 值,見
# NationRelationStore.get_war_exhaustion())。切換主角國家後整包重建(_refresh_content()),
# 不做局部刷新——這個畫面資料量小,重建成本可忽略。
#
# TopBar 測試按鈕一次把六國好感度全部 +10,方便不用真的打贏戰鬥就能測試等級/進度條變化。
# NationFavorStore.changed 只在目前停留在「友好度」畫面時觸發重建,停留在「邦交狀態」
# 畫面時不動——切回「友好度」時 _refresh_content() 本來就會重建成最新資料。
# =========================================================

const VIEW_FAVOR := 0
const VIEW_WAR := 1

const FAVOR_TEST_AMOUNT := 10

## 國旗貼圖尺寸(見 Images/NationFlag/、GameEnums.bloodline_nation_flag_path())——跟
## stronghold_marriage_panel.gd 寄信國家按鈕同一套尺寸,全專案國旗一律用這個大小,
## 一眼認得出是同一組素材。
const FLAG_SIZE := Vector2(140, 210)

## 表格資料列(等級/友好度/進度/狀態/衝突值/疲憊值)單一格子尺寸,寬度跟 FLAG_SIZE.x
## 對齊,同一欄國旗跟其下數值才會對得整齊。
const STAT_CELL_SIZE := Vector2(FLAG_SIZE.x, 50.0)
const STAT_LABEL_COLUMN_WIDTH := 100.0

const FAVOR_BAR_HEIGHT := 18.0
const FAVOR_BAR_BG := Color(0.25, 0.18, 0.1)

@onready var main_panel: PanelContainer = $MainPanel
@onready var main_margin: MarginContainer = $MainPanel/Margin
@onready var test_favor_button: Button = $TopBar/TestFavorButton
@onready var back_button: Button = $TopBar/BackButton
@onready var sidebar: PanelContainer = $Sidebar
@onready var favor_button: Button = $Sidebar/Margin/VBox/FavorButton
@onready var war_button: Button = $Sidebar/Margin/VBox/WarButton

## 目前選中的畫面,預設「友好度」,對應 nation_relations.tscn 的 FavorButton button_pressed = true。
var _current_view: int = VIEW_FAVOR
## 「邦交狀態」目前選定要當主角查看的國家,-1 表示尚未選過,_build_war_view() 第一次
## 建構時會補預設值(六國清單第一個)。
var _selected_war_nation: int = -1


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

	if _current_view == VIEW_FAVOR:
		main_margin.add_child(_build_favor_view())
	else:
		main_margin.add_child(_build_war_view())


func _on_favor_store_changed() -> void:
	if _current_view == VIEW_FAVOR:
		_refresh_content()


## 「國旗欄 x 友好等級/友好度/進度列」表格,見檔頭註解。
func _build_favor_view() -> Control:
	var nations := NationLibrary.get_all()
	var grid := GridContainer.new()
	grid.columns = nations.size() + 1
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)

	grid.add_child(_build_table_blank_cell(STAT_LABEL_COLUMN_WIDTH))
	for nation in nations:
		grid.add_child(_build_nation_header_cell(nation))

	grid.add_child(_build_stat_row_label("友好等級"))
	for nation in nations:
		grid.add_child(_build_favor_rank_cell(nation))

	grid.add_child(_build_stat_row_label("友好度"))
	for nation in nations:
		grid.add_child(_build_favor_value_cell(nation))

	grid.add_child(_build_stat_row_label("進度"))
	for nation in nations:
		grid.add_child(_build_favor_progress_cell(nation))

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(grid)
	return center


func _build_favor_rank_cell(nation: Nation) -> Control:
	var favor := NationFavorStore.get_favor(nation.id)
	return _build_stat_value_cell(NationFavorRank.label_for_favor(favor), UiStyle.PARCHMENT_TEXT_COLOR)


func _build_favor_value_cell(nation: Nation) -> Control:
	return _build_stat_value_cell(str(NationFavorStore.get_favor(nation.id)), UiStyle.PARCHMENT_TEXT_COLOR)


func _build_favor_progress_cell(nation: Nation) -> Control:
	var favor := NationFavorStore.get_favor(nation.id)
	var stage := _favor_stage_progress(favor)

	var cell := PanelContainer.new()
	cell.custom_minimum_size = STAT_CELL_SIZE
	cell.add_theme_stylebox_override("panel", UiStyle.parchment_row_style())

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 4)
	cell.add_child(column)

	var bar := _build_favor_bar(nation.id, stage)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(bar)

	var text_label := Label.new()
	text_label.text = stage["text"]
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.add_theme_font_size_override("font_size", 13)
	text_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_SUBTITLE_COLOR)
	column.add_child(text_label)

	return cell


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


## 最上排六國國旗切換鈕 + 下方主角國家對其餘五國的關係表格,見檔頭註解。
func _build_war_view() -> Control:
	var nations := NationLibrary.get_all()
	if _selected_war_nation == -1:
		_selected_war_nation = nations[0].id

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL

	column.add_child(_build_war_nation_selector(nations))

	var others: Array[Nation] = []
	for nation in nations:
		if nation.id != _selected_war_nation:
			others.append(nation)

	var table_wrap := CenterContainer.new()
	table_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	table_wrap.add_child(_build_war_relation_table(_selected_war_nation, others))
	column.add_child(table_wrap)

	return column


func _build_war_nation_selector(nations: Array[Nation]) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)

	var group := ButtonGroup.new()
	for nation in nations:
		row.add_child(_build_war_nation_button(nation, group))

	return row


func _build_war_nation_button(nation: Nation, group: ButtonGroup) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = load(GameEnums.bloodline_nation_flag_path(nation.id)) as Texture2D
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.custom_minimum_size = FLAG_SIZE
	button.toggle_mode = true
	button.button_group = group
	button.tooltip_text = nation.name

	var is_selected := nation.id == _selected_war_nation
	button.button_pressed = is_selected
	button.modulate = Color.WHITE if is_selected else Color(1, 1, 1, 0.7)

	# 整包重建(_refresh_content())取代局部刷新,下一輪 _build_war_nation_button() 會
	# 依最新的 _selected_war_nation 重新算 modulate,這裡不需要自己在 toggled 裡動態改。
	button.toggled.connect(func(pressed: bool) -> void:
		if not pressed:
			return
		_selected_war_nation = nation.id
		_refresh_content()
	)
	return button


func _build_war_relation_table(selected_id: int, others: Array[Nation]) -> Control:
	var grid := GridContainer.new()
	grid.columns = others.size() + 1
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)

	grid.add_child(_build_table_blank_cell(STAT_LABEL_COLUMN_WIDTH))
	for other in others:
		grid.add_child(_build_nation_header_cell(other))

	grid.add_child(_build_stat_row_label("狀態"))
	for other in others:
		grid.add_child(_build_war_status_cell(selected_id, other.id))

	grid.add_child(_build_stat_row_label("衝突值"))
	for other in others:
		grid.add_child(_build_war_tension_cell(selected_id, other.id))

	grid.add_child(_build_stat_row_label("疲憊值"))
	for other in others:
		grid.add_child(_build_war_exhaustion_cell(selected_id, other.id))

	return grid


func _build_war_status_cell(nation_a: int, nation_b: int) -> Control:
	var status := NationRelation.get_status(nation_a, nation_b)
	return _build_stat_value_cell(GameEnums.nation_war_status_label(status), UiStyle.PARCHMENT_TEXT_COLOR)


func _build_war_tension_cell(nation_a: int, nation_b: int) -> Control:
	var tension := NationRelation.get_tension(nation_a, nation_b)
	return _build_stat_value_cell("%.0f%%" % tension, UiStyle.PARCHMENT_TEXT_COLOR)


## 疲憊值只在雙方真的交戰中才有非 0 值(見 NationRelationStore.get_war_exhaustion()),
## 顯示的是「other」這一方的疲憊——讀者視角是「選定國家的這個對手打得多累」,承平狀態
## 下直接回傳 0、顯示「0%」,不特別另外顯示「-」(語意上「沒在打就不會累」)。
func _build_war_exhaustion_cell(selected_id: int, other_id: int) -> Control:
	var exhaustion := NationRelation.get_exhaustion(selected_id, other_id, other_id)
	return _build_stat_value_cell("%.0f%%" % exhaustion, UiStyle.PARCHMENT_TEXT_COLOR)


func _build_table_blank_cell(min_width: float) -> Control:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(min_width, 0)
	cell.add_theme_stylebox_override("panel", UiStyle.parchment_row_style())
	return cell


## 表頭改用國旗(見 _build_nation_flag()),不含文字國名——邊框留 0 內距,避免格子
## 尺寸比 FLAG_SIZE 本身還大一圈。友好度/邦交狀態兩張表共用。
func _build_nation_header_cell(nation: Nation) -> Control:
	var cell := PanelContainer.new()
	cell.add_theme_stylebox_override("panel", UiStyle.parchment_row_style(UiStyle.PARCHMENT_ROW_BORDER, 2, 8, 0.0, 0.0))
	cell.add_child(_build_nation_flag(nation.id))
	return cell


## 國旗貼圖建構共用邏輯,尺寸統一 FLAG_SIZE,比照 stronghold_marriage_panel.gd 寄信
## 國家按鈕/family_tree.gd 家族旗幟的 TextureRect 設定方式。
func _build_nation_flag(nation_id: int) -> TextureRect:
	var flag := TextureRect.new()
	flag.custom_minimum_size = FLAG_SIZE
	flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	flag.texture = load(GameEnums.bloodline_nation_flag_path(nation_id))
	flag.tooltip_text = GameEnums.bloodline_nation_label(nation_id)
	return flag


## 表格資料格共用外觀(等級/友好度/狀態/衝突值/疲憊值都是「一顆羊皮紙邊框格子 + 一行
## 置中文字」的形狀,只有文字內容跟顏色不同)。進度格因為要多塞一條進度條,不套這個,
## 見 _build_favor_progress_cell()。
func _build_stat_value_cell(text: String, color: Color) -> Control:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = STAT_CELL_SIZE
	cell.add_theme_stylebox_override("panel", UiStyle.parchment_row_style())

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", color)
	cell.add_child(label)
	return cell


func _build_stat_row_label(text: String) -> Control:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(STAT_LABEL_COLUMN_WIDTH, STAT_CELL_SIZE.y)
	cell.add_theme_stylebox_override("panel", UiStyle.parchment_row_style())

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", UiStyle.PARCHMENT_SUBTITLE_COLOR)
	cell.add_child(label)
	return cell


func _on_test_favor_pressed() -> void:
	for nation_id in GameEnums.BloodlineNation.values():
		NationFavorStore.add_favor(nation_id, FAVOR_TEST_AMOUNT)


func _on_back_pressed() -> void:
	NavigationStore.go_back()
