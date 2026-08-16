class_name CharacterCard
extends PanelContainer

# =========================================================
# 右側候補角色清單的一張卡片:頭像 + 姓名/等級/武器/六大素質 + battle_cost 形狀,
# 也是「拖到左側網格」這個操作的拖曳來源。程式化建構節點,
# 比照 battle_report_list.gd/_populate_skills() 等既有清單列慣例,
# 不另外拆一個 .tscn。
#
# CARD_MIN_HEIGHT 只是底線——battle_cost 最高可以長到 6 格縱向(見
# BattleCostController.MAX_CELLS)再加上站立圖示比例撐出來的溢出(見
# BattleCostView._standee_rect()),實際高度由 HBoxContainer 取三欄
# (頭像/資訊/形狀)最高者自動撐開,不會被這個底線刻意壓扁裁切。
# =========================================================

const CARD_MIN_HEIGHT := 112.0
const CARD_COST_CELL_SIZE := 16.0
const FACE_SIZE := Vector2(80, 80)
const WEAPON_ICON_SIZE := Vector2(18, 18)
const NAME_FONT_SIZE := 16
const STAT_FONT_SIZE := 13

var character: Character

## 拖曳門檻觸發後 _get_drag_data() 會先設 true,擋掉隨後那次放開滑鼠的
## _gui_input——不然「拖去網格放置」放開滑鼠那一下會被誤判成單純的輕點,
## 多彈出一個 CharacterPanel。NOTIFICATION_DRAG_END 統一重置回 false。
var _dragging := false

func _init(p_character: Character = null) -> void:
	character = p_character


func _ready() -> void:
	custom_minimum_size = Vector2(0, CARD_MIN_HEIGHT)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_stylebox_override("panel", UiStyle.bordered_panel(
		Color(0.13, 0.15, 0.21, 0.95), Color(0.36, 0.4, 0.56, 1), 2, 8, 10.0, 4.0
	))

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	add_child(content)

	var face_center := CenterContainer.new()
	content.add_child(face_center)

	var face := TextureRect.new()
	face.custom_minimum_size = FACE_SIZE
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_SCALE
	if not character.face_path.is_empty():
		face.texture = load(character.face_path) as Texture2D
	face_center.add_child(face)

	var info_column := VBoxContainer.new()
	info_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_column.alignment = BoxContainer.ALIGNMENT_CENTER
	info_column.add_theme_constant_override("separation", 4)
	content.add_child(info_column)

	var name_label := Label.new()
	name_label.text = character.full_name
	name_label.add_theme_font_size_override("font_size", NAME_FONT_SIZE)
	info_column.add_child(name_label)

	var level_weapon_row := HBoxContainer.new()
	level_weapon_row.add_theme_constant_override("separation", 8)
	info_column.add_child(level_weapon_row)

	var level_label := Label.new()
	level_label.text = "等級 %d" % character.level_system.level
	level_label.add_theme_font_size_override("font_size", STAT_FONT_SIZE)
	level_weapon_row.add_child(level_label)

	var weapon_icon := TextureRect.new()
	weapon_icon.custom_minimum_size = WEAPON_ICON_SIZE
	weapon_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	weapon_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	weapon_icon.texture = load(GameEnums.weapon_icon_path(character.weapon)) as Texture2D
	weapon_icon.tooltip_text = GameEnums.weapon_label(character.weapon)
	level_weapon_row.add_child(weapon_icon)

	## 排列順序跟 CharacterDetailView.POTENTIAL_GRID_ORDER 共用,兩處呈現同一套
	## 「力量/敏捷、體質/靈巧、智慧/意志」慣例,不要各自維護一份順序。
	var potential_grid := GridContainer.new()
	potential_grid.columns = 2
	potential_grid.add_theme_constant_override("h_separation", 16)
	potential_grid.add_theme_constant_override("v_separation", 2)
	info_column.add_child(potential_grid)

	for potential_type in CharacterDetailView.POTENTIAL_GRID_ORDER:
		var stat_label := Label.new()
		stat_label.text = "%s %d" % [GameEnums.potential_label(potential_type), roundi(character.get_potential(potential_type))]
		stat_label.add_theme_font_size_override("font_size", STAT_FONT_SIZE)
		potential_grid.add_child(stat_label)

	var cost_center := CenterContainer.new()
	content.add_child(cost_center)

	var cost_view := BattleCostView.new()
	cost_view.cell_size = CARD_COST_CELL_SIZE
	cost_view.weapon = character.weapon
	cost_view.battle_cost = character.battle_cost
	cost_center.add_child(cost_view)


func _get_drag_data(_at_position: Vector2):
	_dragging = true
	var preview := BattleCostView.build_centered_drag_preview(character.battle_cost.cells.duplicate(), PartyEditBoard.TILE_SIZE, character.weapon)
	set_drag_preview(preview)
	modulate.a = 0.4

	return {
		"type": "battle_cost_placement",
		"character": character,
		"shape": character.battle_cost.cells.duplicate(),
		"preview": preview,
		"origin": "roster",
	}


## 輕點(按下又放開,中途沒有拉出拖曳)開啟共用角色面板,跟戰場點頭像/點場上
## 角色本人同一套(見 battle_party_roster.gd 的 _on_portrait_gui_input()、
## battle_unit_visual.gd 的 _on_click_area_input_event())。
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if not _dragging:
			CharacterPanel.open_for_character(character)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		modulate.a = 1.0
		_dragging = false
