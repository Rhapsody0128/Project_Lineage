class_name BattleCostController
extends RefCounted

const MIN_CELLS := 3
const MAX_CELLS := 6
const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

## 從固定種子格 Vector2i.ZERO 開始隨機生長(flood-fill):每步從目前形狀相鄰的
## 空格(frontier)隨機挑一格併入,直到湊滿隨機格數。純粹靠鄰接規則長出任意
## 連通的多格圖形,不窮舉/枚舉具名形狀(不是 if L型/T型/口字型的表)。
static func get_random_battle_cost() -> BattleCost:
	var target_count := Util.get_random_int(MIN_CELLS, MAX_CELLS + 1)
	var cells: Array[Vector2i] = [Vector2i.ZERO]
	var frontier: Array[Vector2i] = _neighbors_not_in(Vector2i.ZERO, cells, [])

	while cells.size() < target_count:
		var next: Vector2i = Util.get_random_from_array(frontier)
		frontier.erase(next)
		cells.append(next)
		for neighbor in _neighbors_not_in(next, cells, frontier):
			frontier.append(neighbor)

	return BattleCost.new(cells)

static func _neighbors_not_in(cell: Vector2i, cells: Array[Vector2i], frontier: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for offset in DIRECTIONS:
		var neighbor := cell + offset
		if not cells.has(neighbor) and not frontier.has(neighbor):
			result.append(neighbor)
	return result
