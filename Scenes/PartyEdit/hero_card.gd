class_name HeroCard
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

var hero: Hero

func _init(p_hero: Hero = null) -> void:
	hero = p_hero


func _ready() -> void:
	custom_minimum_size = Vector2(0, CARD_MIN_HEIGHT)
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
	if not hero.face_path.is_empty():
		face.texture = load(hero.face_path) as Texture2D
	content.add_child(face)

	var name_label := Label.new()
	name_label.text = hero.full_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(name_label)

	var cost_view := BattleCostView.new()
	cost_view.cell_size = CARD_COST_CELL_SIZE
	cost_view.weapon = hero.weapon
	cost_view.battle_cost = hero.battle_cost
	content.add_child(cost_view)


func _get_drag_data(_at_position: Vector2):
	var preview := BattleCostView.build_centered_drag_preview(hero.battle_cost.cells.duplicate(), PartyEditBoard.TILE_SIZE, hero.weapon)
	set_drag_preview(preview)
	modulate.a = 0.4

	return {
		"type": "battle_cost_placement",
		"hero": hero,
		"shape": hero.battle_cost.cells.duplicate(),
		"preview": preview,
		"origin": "roster",
	}


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		modulate.a = 1.0
