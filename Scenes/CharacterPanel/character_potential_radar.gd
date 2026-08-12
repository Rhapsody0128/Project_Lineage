class_name CharacterPotentialRadar
extends Control

# =========================================================
# 角色六大素質雷達圖(力量/體質/敏捷/靈巧/智慧/信仰)。
# 純粹畫面呈現,只依傳入的 Hero 目前數值(已含等級加成)畫圖,
# 不含任何數值判定邏輯。
# =========================================================

const AXIS_COUNT := 6
const RING_COUNT := 4
const MAX_VALUE := 200.0
const LABEL_MARGIN := 26.0
const FONT_SIZE := 14

const GRID_COLOR := Color(1, 1, 1, 0.25)
const AXIS_LABEL_COLOR := Color(0.85, 0.85, 0.9)
const FILL_COLOR := Color(0.4, 0.7, 1.0, 0.35)
const OUTLINE_COLOR := Color(0.55, 0.8, 1.0, 0.9)

const POTENTIAL_TYPES := [
	GameEnums.PotentialType.STRENGTH,
	GameEnums.PotentialType.VITALITY,
	GameEnums.PotentialType.AGILITY,
	GameEnums.PotentialType.PERCEPTION,
	GameEnums.PotentialType.INTELLIGENCE,
	GameEnums.PotentialType.MENTALITY,
]

var _hero: Hero


func set_hero(p_hero: Hero) -> void:
	_hero = p_hero
	queue_redraw()


func _draw() -> void:
	if _hero == null:
		return

	var center := size / 2.0
	var radius := minf(size.x, size.y) / 2.0 - LABEL_MARGIN
	if radius <= 0.0:
		return

	_draw_grid(center, radius)
	_draw_values(center, radius)
	_draw_labels(center, radius)


func _axis_point(center: Vector2, radius: float, index: int) -> Vector2:
	var angle := -PI / 2.0 + index * (TAU / AXIS_COUNT)
	return center + Vector2(cos(angle), sin(angle)) * radius


func _draw_grid(center: Vector2, radius: float) -> void:
	for ring in range(1, RING_COUNT + 1):
		var ring_radius := radius * ring / float(RING_COUNT)
		var points := PackedVector2Array()
		for i in range(AXIS_COUNT + 1):
			points.append(_axis_point(center, ring_radius, i % AXIS_COUNT))
		draw_polyline(points, GRID_COLOR, 1.0)

	for i in range(AXIS_COUNT):
		draw_line(center, _axis_point(center, radius, i), GRID_COLOR, 1.0)


func _draw_values(center: Vector2, radius: float) -> void:
	var points := PackedVector2Array()
	for i in range(AXIS_COUNT):
		var value: float = _hero.get_potential(POTENTIAL_TYPES[i])
		var ratio: float = clampf(value / MAX_VALUE, 0.0, 1.0)
		points.append(_axis_point(center, radius * ratio, i))

	if points.size() < 3:
		return

	draw_colored_polygon(points, FILL_COLOR)

	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, OUTLINE_COLOR, 2.0)


func _draw_labels(center: Vector2, radius: float) -> void:
	var font := get_theme_default_font()
	var font_size := FONT_SIZE

	for i in range(AXIS_COUNT):
		var label: String = GameEnums.POTENTIAL_TYPE_LABELS[i]
		var anchor := _axis_point(center, radius + LABEL_MARGIN * 0.7, i)
		var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		draw_string(
			font,
			anchor - Vector2(text_size.x / 2.0, -text_size.y / 4.0),
			label,
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			font_size,
			AXIS_LABEL_COLOR
		)
