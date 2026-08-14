class_name CharacterPotentialRadar
extends Control

# =========================================================
# 角色六大素質雷達圖(力量/體質/敏捷/靈巧/智慧/信仰)。
# 純粹畫面呈現,只依傳入的 Hero 目前數值(已含等級加成)畫圖,
# 不含任何數值判定邏輯。
#
# 從戰鬥場景(點頭像)開啟時會多帶一個 BattleHero(見 set_hero() 的第二參數)——
# 這時雷達圖形狀本身跟標籤數字都改用 BattleHero.get_potential()(套用完暴擊/被動/
# buff/debuff 加成後的即時數值),標籤格式變成「力量 SSS 60 (86)」,括號裡是戰場當下
# 的即時值;沒有 BattleHero(例如創角面板)時維持只顯示基礎潛力數字。
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
	GameEnums.PotentialType.DEXTERITY,
	GameEnums.PotentialType.INTELLIGENCE,
	GameEnums.PotentialType.MENTALITY,
]

var _hero: Hero
var _battle_hero: BattleHero


## battle_hero 留空(null)代表沒有戰場情境(創角面板等),只顯示基礎潛力數字;
## 有傳入時代表是從戰鬥中點頭像開啟,額外顯示即時數值,並持續每幀重繪跟上戰況變化
## (見 _process())。
func set_hero(p_hero: Hero, p_battle_hero: BattleHero = null) -> void:
	_hero = p_hero
	_battle_hero = p_battle_hero
	set_process(_battle_hero != null)
	queue_redraw()


## 只有帶 BattleHero(戰鬥中開啟)才需要逐幀重繪——素質會因為 buff/debuff/被動隨戰況
## 即時變動,面板開著的時候要連動更新;沒有 BattleHero 時數值不會變,不需要浪費效能。
func _process(_delta: float) -> void:
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


## 有 BattleHero 時,雷達圖的形狀本身也改畫即時數值(不然形狀跟旁邊標出來的即時數字對不上)。
func _current_value(potential_type: int) -> float:
	if _battle_hero != null:
		return _battle_hero.get_potential(potential_type)
	return _hero.get_potential(potential_type)


func _draw_values(center: Vector2, radius: float) -> void:
	var points := PackedVector2Array()
	for i in range(AXIS_COUNT):
		var value := _current_value(POTENTIAL_TYPES[i])
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
		var potential_type: int = POTENTIAL_TYPES[i]
		var rank: int = _hero.get_potential_rank(potential_type)
		var base_value: int = roundi(_hero.get_potential(potential_type))

		var label: String
		if _battle_hero != null:
			var live_value: int = roundi(_battle_hero.get_potential(potential_type))
			label = "%s %s %d (%d)" % [GameEnums.potential_label(i), GameEnums.rank_label(rank), base_value, live_value]
		else:
			label = "%s %s %d" % [GameEnums.potential_label(i), GameEnums.rank_label(rank), base_value]

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
