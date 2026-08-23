class_name FamilyTreeCanvas
extends Control

# =========================================================
# 祖譜樹狀圖本體:render(focus) 呼叫 FamilyTreeBuilder.build() 拿到 FamilyTreeUnit
# 陣列,自己算版面座標(後序遞迴分配 x slot、generation 決定 y)後手動 position/size
# 每張卡片(不靠 Container 排版——節點數量/位置都要動態算,固定 Container 排不出
# 樹狀圖),再覆寫 _draw() 畫世代之間的直角連接線。放在 family_tree.tscn 的
# ScrollContainer 底下,custom_minimum_size 撐開成整棵樹的實際範圍,ScrollContainer
# 才滾得到全部內容。
#
# 卡片內容比照使用者需求:「本人 | 配偶」左右兩欄,每欄左上頭像、右上姓名/年齡/
# 性別/血統評級(Character.noble_bloodline_rank)並排,下面一條分隔線接血統清單
# (含百分比計量表,資料來源/配色跟
# CharacterDetailView._populate_bloodline() 一致;固定只留約 3~4 條的高度,超過用
# ScrollContainer 內部捲動,不撐高卡片)。沒有配偶時卡片只有一欄、不留空欄——所以
# 卡片寬度依 unit 是否有 partner 分兩種(CARD_WIDTH_SINGLE/CARD_WIDTH_COUPLE),但
# 仍統一用同一個 slot pitch(取兩者較寬的 CARD_WIDTH_COUPLE 為準)置中排列,卡片
# 幾何中心(_rect_by_unit 存的 Rect2)永遠等於「本人跟配偶之間的中線」(單人卡就是
# 那一欄本身的中線),連接線直接讀這個中心點,不用另外校正。
#
# FamilyTreeBuilder.build() 會沿 children/parent/mate 三種邊走完 focus 所在的整個連通
# 親族圖(父母、祖父母、配偶、子女、孫子女……都算),往上追出來的最上層那一代才是世代 1
# (樹頂),focus 不一定是世代 1。
#
# 點卡片任一欄(整欄都能點,不是只有小頭像)開 CharacterPanel;整個 ScrollContainer
# 範圍內也能按住拖曳平移(_input() 而非 _gui_input(),見下方拖曳段落)。
# =========================================================

## CARD_HEIGHT/CARD_WIDTH_*/COLUMN_WIDTH 比原本各拉高/拉寬一截,多留給新增的
## 「血統評級」列(見 _build_person_column())——連接線的置中邏輯(_draw()/
## render() 的 slot_center_x)完全是從這幾個常數即時算出來的,不是寫死座標,
## 這裡調整不需要另外校正祖譜線。
const CARD_HEIGHT := 272.0
const CARD_WIDTH_SINGLE := 260.0
const CARD_WIDTH_COUPLE := 520.0
const SLOT_GAP := 70.0
const ROW_GAP := 90.0
const CANVAS_MARGIN := 40.0
const COLUMN_WIDTH := 230.0
const PORTRAIT_SIZE := Vector2(56, 56)

const PANEL_BG := Color(0.13, 0.15, 0.21, 0.95)
const PANEL_BORDER := Color(0.36, 0.4, 0.56, 1)
const LINE_COLOR := Color(0.95, 0.9, 0.72, 1)
const LINE_WIDTH := 3.0

## 血統評級文字色,跟 CharacterDetailView.BLOODLINE_RANK_COLOR 同一套金色,
## 兩處都是「評級」語意,視覺語言統一。
const BLOODLINE_RANK_COLOR := Color(1.0, 0.85, 0.3)

const BLOODLINE_BAR_HEIGHT := 8.0
const BLOODLINE_BAR_FILL := Color(0.75, 0.78, 0.86)
const BLOODLINE_BAR_BG := Color(0.1, 0.1, 0.12)
## 血統清單固定只留約 3~4 條的高度,超過的用 ScrollContainer 內部捲動,不撐高卡片。
const BLOODLINE_LIST_HEIGHT := 140.0

## 拖曳判定:按住移動超過這個距離(像素)才算「有拖曳」,放開時才不會被
## _on_person_gui_input 誤判成單純點擊而開錯的 CharacterPanel。
const DRAG_MOVE_THRESHOLD := 4.0

var _units: Array[FamilyTreeUnit] = []
var _rect_by_unit: Dictionary = {}
var _next_leaf_slot: float = 0.0
var _slot_by_unit: Dictionary = {}

var _scroll_container: ScrollContainer
var _dragging: bool = false
var _drag_moved: bool = false
var _drag_distance: float = 0.0


func _ready() -> void:
	_scroll_container = get_parent() as ScrollContainer


func render(focus: Character) -> void:
	for child in get_children():
		child.queue_free()

	_units = FamilyTreeBuilder.build(focus)
	_rect_by_unit.clear()
	_slot_by_unit.clear()
	_next_leaf_slot = 0.0

	if _units.is_empty():
		queue_redraw()
		return

	var root_units: Array[FamilyTreeUnit] = []
	for unit in _units:
		if unit.parent_unit == null:
			root_units.append(unit)
	for root in root_units:
		_assign_slot(root)

	var pitch := CARD_WIDTH_COUPLE + SLOT_GAP
	var row_height := CARD_HEIGHT + ROW_GAP
	var max_right := 0.0
	var max_bottom := 0.0

	for unit in _units:
		var slot: float = _slot_by_unit[unit]
		var card_width: float = CARD_WIDTH_COUPLE if unit.partner != null else CARD_WIDTH_SINGLE
		var slot_center_x: float = slot * pitch + pitch / 2.0
		var rect := Rect2(
			Vector2(slot_center_x - card_width / 2.0, float(unit.generation - 1) * row_height),
			Vector2(card_width, CARD_HEIGHT)
		)
		_rect_by_unit[unit] = rect

		var card := _build_card(unit)
		card.position = rect.position
		card.size = rect.size
		add_child(card)

		max_right = max(max_right, rect.position.x + rect.size.x)
		max_bottom = max(max_bottom, rect.position.y + rect.size.y)

	custom_minimum_size = Vector2(max_right + CANVAS_MARGIN, max_bottom + CANVAS_MARGIN)
	queue_redraw()


## 後序遞迴:葉節點(沒有 child_units)依序拿下一個遞增的 slot index,有子節點的
## Unit 的 slot 取子節點 slot 的平均值——子節點群才會在視覺上置中在上一代下方。
func _assign_slot(unit: FamilyTreeUnit) -> float:
	if unit.child_units.is_empty():
		var slot := _next_leaf_slot
		_next_leaf_slot += 1.0
		_slot_by_unit[unit] = slot
		return slot

	var total := 0.0
	for child_unit in unit.child_units:
		total += _assign_slot(child_unit)
	var slot: float = total / unit.child_units.size()
	_slot_by_unit[unit] = slot
	return slot


func _draw() -> void:
	for unit in _units:
		if unit.child_units.is_empty():
			continue

		var parent_rect: Rect2 = _rect_by_unit[unit]
		var parent_center_x: float = parent_rect.position.x + parent_rect.size.x / 2.0
		var parent_bottom := Vector2(parent_center_x, parent_rect.position.y + parent_rect.size.y)
		var bus_y := parent_rect.position.y + parent_rect.size.y + ROW_GAP / 2.0

		var min_x: float = parent_center_x
		var max_x: float = parent_center_x
		for child_unit in unit.child_units:
			var child_rect: Rect2 = _rect_by_unit[child_unit]
			var child_x: float = child_rect.position.x + child_rect.size.x / 2.0
			min_x = min(min_x, child_x)
			max_x = max(max_x, child_x)

		draw_line(parent_bottom, Vector2(parent_center_x, bus_y), LINE_COLOR, LINE_WIDTH)
		draw_line(Vector2(min_x, bus_y), Vector2(max_x, bus_y), LINE_COLOR, LINE_WIDTH)
		for child_unit in unit.child_units:
			var child_rect: Rect2 = _rect_by_unit[child_unit]
			var child_top := Vector2(child_rect.position.x + child_rect.size.x / 2.0, child_rect.position.y)
			draw_line(Vector2(child_top.x, bus_y), child_top, LINE_COLOR, LINE_WIDTH)


func _build_card(unit: FamilyTreeUnit) -> PanelContainer:
	var card := PanelContainer.new()
	card.clip_contents = true
	card.add_theme_stylebox_override("panel", UiStyle.bordered_panel(PANEL_BG, PANEL_BORDER, 2, 10, 12.0, 10.0))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)

	row.add_child(_build_person_column(unit.primary))
	if unit.partner != null:
		row.add_child(VSeparator.new())
		row.add_child(_build_person_column(unit.partner))

	return card


## 整欄(頭像+姓名+年齡+性別+血統)都能點擊開 CharacterPanel,不是只有小頭像那一小塊
## ——蓋一層跟欄位等大的透明 click_catcher 疊在最上面當最後一個 child(命中測試從
## 後面的 sibling 先測,直接攔截整欄範圍的點擊,底下內容不用逐一設定 mouse_filter)。
## 用「放開且沒有明顯拖曳過」才觸發開面板(讀 _drag_moved,見 _input()),拖曳平移
## 放開時不會被誤判成點擊。
func _build_person_column(character: Character) -> Control:
	var wrapper := Control.new()
	wrapper.custom_minimum_size = Vector2(COLUMN_WIDTH, 0)
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var content := VBoxContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.add_theme_constant_override("separation", 6)
	wrapper.add_child(content)

	## 左上頭像 + 右上姓名/年齡/性別並排(不是頭像置中疊上面、資訊往下堆),下面用一條
	## 分隔線隔開血統清單,比照使用者要的排版。
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	content.add_child(top_row)

	var portrait := TextureRect.new()
	portrait.custom_minimum_size = PORTRAIT_SIZE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_SCALE
	# Control 預設 size_flags_vertical 是 SIZE_FILL,HBoxContainer 會把它撐到跟
	# info_column 一樣高——新增血統評級那列之後 info_column 變得比 PORTRAIT_SIZE 高,
	# 沒有這行頭像就會被垂直拉伸變形。SHRINK_CENTER 讓它固定維持 PORTRAIT_SIZE 正方形,
	# 高度不夠的部分置中,不跟著 info_column 撐高。
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not character.face_path.is_empty():
		portrait.texture = load(character.face_path) as Texture2D
	top_row.add_child(portrait)

	var info_column := VBoxContainer.new()
	info_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_column.add_theme_constant_override("separation", 2)
	top_row.add_child(info_column)

	info_column.add_child(_build_stat_row("姓名", character.full_name, 14))
	info_column.add_child(_build_stat_row("年齡", "%d歲" % character.age, 12))
	info_column.add_child(_build_stat_row("狀態", CharacterStatusRule.get_status_label(character), 12))
	info_column.add_child(_build_stat_row("性別", GameEnums.gender_symbol(character.gender), 12))

	var rank_row := _build_stat_row("血統評級", GameEnums.rank_label(character.noble_bloodline_rank), 12)
	rank_row.get_child(1).add_theme_color_override("font_color", BLOODLINE_RANK_COLOR)
	info_column.add_child(rank_row)

	content.add_child(HSeparator.new())

	var bloodline_list := VBoxContainer.new()
	bloodline_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bloodline_list.add_theme_constant_override("separation", 6)
	if character.bloodline != null:
		for entry in character.bloodline.get_nonzero_entries():
			bloodline_list.add_child(_build_bloodline_entry(entry))

	var bloodline_scroll := ScrollContainer.new()
	bloodline_scroll.custom_minimum_size = Vector2(0, BLOODLINE_LIST_HEIGHT)
	bloodline_scroll.size_flags_vertical = Control.SIZE_FILL
	bloodline_scroll.add_child(bloodline_list)
	content.add_child(bloodline_scroll)

	var click_catcher := Control.new()
	click_catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	click_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	click_catcher.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	click_catcher.gui_input.connect(_on_person_gui_input.bind(character))
	wrapper.add_child(click_catcher)

	return wrapper


## 血統一條「標籤+百分比」列 + 底下一條計量表,資料來源/配色跟
## CharacterDetailView._populate_bloodline() 一致(NOBLE 階級文字上色);祖譜卡片
## 空間有限,計量表縮窄一點(BLOODLINE_BAR_HEIGHT 比 CharacterDetailView 原本小)。
func _build_bloodline_entry(entry: Dictionary) -> Control:
	var nation: int = entry["nation"]
	var rank: int = entry["rank"]
	var percentage: float = entry["percentage"]

	var entry_column := VBoxContainer.new()
	entry_column.add_theme_constant_override("separation", 2)

	var row := _build_stat_row(GameEnums.bloodline_full_label(nation, rank), "%.1f%%" % percentage)
	if rank == GameEnums.BloodlineRank.NOBLE:
		var nation_color := GameEnums.bloodline_nation_color(nation)
		row.get_child(0).add_theme_color_override("font_color", nation_color)
		row.get_child(1).add_theme_color_override("font_color", nation_color)
	entry_column.add_child(row)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, BLOODLINE_BAR_HEIGHT)
	bar.max_value = Bloodline.TOTAL
	bar.value = percentage
	bar.show_percentage = false

	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = BLOODLINE_BAR_FILL
	bar_fill.set_corner_radius_all(int(BLOODLINE_BAR_HEIGHT / 2.0))
	bar.add_theme_stylebox_override("fill", bar_fill)

	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = BLOODLINE_BAR_BG
	bar_bg.set_corner_radius_all(int(BLOODLINE_BAR_HEIGHT / 2.0))
	bar.add_theme_stylebox_override("background", bar_bg)

	entry_column.add_child(bar)
	return entry_column


## caption 靠左、value 靠右的兩端對齊列(space between),血統清單跟姓名/年齡/性別
## 資訊列共用同一個 helper——後者字級不同(姓名 14 大一點跟年齡/性別區分主次),
## 所以開放 font_size 覆寫,預設沿用血統列原本的 12。
##
## 注意:expand-fill 要放在 value_label 而不是 caption_label——caption 都是「姓名」
## 「年齡」這種固定短字,不需要搶空間;value(尤其姓名)長度不固定,才需要吃剩餘
## 寬度。clip_text=true 會讓 Label 的 minimum_size 直接算成 0(讓它可以被裁切),
## 如果沒有另外用 size_flags_horizontal=EXPAND_FILL 讓它分到實際寬度,裁切後寬度就是
## 0,文字整個看不見——不是資料不見,是版位被算成 0 寬度,曾經踩過這個雷。
func _build_stat_row(caption: String, value: String, font_size: int = 12) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	var caption_label := Label.new()
	caption_label.text = caption
	caption_label.add_theme_font_size_override("font_size", font_size)
	row.add_child(caption_label)

	var value_label := Label.new()
	value_label.text = value
	value_label.add_theme_font_size_override("font_size", font_size)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.clip_text = true
	row.add_child(value_label)

	return row


func _on_person_gui_input(input_event: InputEvent, character: Character) -> void:
	if input_event is InputEventMouseButton and input_event.button_index == MOUSE_BUTTON_LEFT and not input_event.pressed:
		if not _drag_moved:
			CharacterPanel.open_for_character(character)


## 拖曳平移:用 _input() 而不是 _gui_input()——不受卡片/click_catcher 的
## mouse_filter=STOP 影響,不管從卡片上方或空白處按下都能拖曳,不用另外幫每個子
## 節點設定 mouse_filter 忽略。按下當下要落在 ScrollContainer 範圍內才開始拖曳
## (避免從返回鍵等處按下也觸發平移);移動距離超過 DRAG_MOVE_THRESHOLD 才算「有
## 拖曳」(_drag_moved),放開時 _on_person_gui_input 讀這個旗標判斷是要開面板還是
## 純粹拖完放開,兩者不會互相誤觸。
func _input(event: InputEvent) -> void:
	if _scroll_container == null:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if not _scroll_container.get_global_rect().has_point(event.position):
				return
			_dragging = true
			_drag_moved = false
			_drag_distance = 0.0
		else:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		var delta: Vector2 = event.relative
		_drag_distance += delta.length()
		if _drag_distance > DRAG_MOVE_THRESHOLD:
			_drag_moved = true
		_scroll_container.scroll_horizontal -= int(delta.x)
		_scroll_container.scroll_vertical -= int(delta.y)
