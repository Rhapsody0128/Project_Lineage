class_name CharacterCard
extends PanelContainer

# =========================================================
# 右側候補角色清單的一張卡片:名稱 + 頭像 + battle_cost 形狀,
# 也是「拖到左側網格」這個操作的拖曳來源。程式化建構節點,
# 比照 battle_report_list.gd/_populate_skills() 等既有清單列慣例,
# 不另外拆一個 .tscn。
# =========================================================

const CARD_MIN_HEIGHT := 72.0
const CARD_COST_CELL_SIZE := 16.0
const FACE_SIZE := Vector2(56, 56)

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
	content.add_theme_constant_override("separation", 10)
	add_child(content)

	var face := TextureRect.new()
	face.custom_minimum_size = FACE_SIZE
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_SCALE
	if not character.face_path.is_empty():
		face.texture = load(character.face_path) as Texture2D
	content.add_child(face)

	var name_label := Label.new()
	name_label.text = character.full_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(name_label)

	var cost_view := BattleCostView.new()
	cost_view.cell_size = CARD_COST_CELL_SIZE
	cost_view.weapon = character.weapon
	cost_view.battle_cost = character.battle_cost
	content.add_child(cost_view)


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
