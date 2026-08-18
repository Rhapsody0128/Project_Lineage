class_name BattleCostController
extends RefCounted

const MIN_CELLS := 3
const MAX_CELLS := 7
const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

## 高階血統評分(GameEnums.RankType)換算戰場佔位格數:兩階一組,格數從 MIN_CELLS
## 起算每往上兩階 +1 格——E/D=3、C/B=4、A/S=5、SS/SSS=6。RankType 最高 SSS=7,
## 7/2 下取整 +MIN_CELLS 剛好等於 MAX_CELLS,兩邊常數本來就對齊,不需要另外 clamp。
static func cells_for_noble_rank(rank: int) -> int:
	return MIN_CELLS + int(rank / 2)

## 從固定種子格 Vector2i.ZERO 開始隨機生長(flood-fill):每步從目前形狀相鄰的
## 空格(frontier)隨機挑一格併入,直到湊滿 target_count 格(見 cells_for_noble_rank()——
## 格數不再隨機骰,由角色的高階血統評分決定,這裡只負責隨機長出形狀)。純粹靠鄰接
## 規則長出任意連通的多格圖形,不窮舉/枚舉具名形狀(不是 if L型/T型/口字型的表)。
static func get_random_battle_cost(target_count: int) -> BattleCost:
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
