class_name MovementPlanner
extends RefCounted

## 移動/尋路的共用計算服務,從 BattleHero 搬出來——BattleHero 只保留「套用移動結果、
## 記事件」的薄封裝(move()/move_away()),實際路徑怎麼走全部在這裡計算,行為不變。

## 每回合預設移動步數
const BASE_MOVE_STEPS := 2
## 每累積這麼多敏捷,多走 1 格
const AGILITY_PER_EXTRA_STEP := 50.0

## 本回合可移動的格數:基礎 2 格,每 50 敏捷多走 1 格
static func move_steps(actor: BattleHero) -> int:
	return BASE_MOVE_STEPS + int(actor.agility / AGILITY_PER_EXTRA_STEP)

## 往目標方向移動(或遠離,away=true),最多走 move_steps(actor) 格(先水平、後垂直),
## 一旦進入 atk_range 就停止,不會多走進更近的格子;途中可以直接穿過己方角色(不擋路),
## 只有敵方角色會擋路,遇到敵方卡住主方向時會側移繞路,而不是直接卡死不動。
## 回傳完整路徑(可能為了繞路而轉彎),呼叫端(BattleHero.move()/move_away())負責
## 實際套用 grid_pos 與記錄 MoveEvent。
static func plan_path(actor: BattleHero, target: BattleHero, away: bool, atk_range: int) -> Array[Vector2i]:
	var pos := actor.grid_pos
	var path: Array[Vector2i] = []
	var steps := move_steps(actor)

	for i in range(steps):
		if not away and _in_range(pos, target.grid_pos, atk_range):
			break
		if away and atk_range > 0 and Util.manhattan_distance(pos, target.grid_pos) >= atk_range:
			break

		var new_pos := _next_step(actor, pos, target, away)
		if new_pos == pos:
			break

		pos = new_pos
		path.append(new_pos)

	# 移動途中可以直接穿過己方角色,但最終落腳點不能剛好疊在任何人身上,
	# 若最後一步撞上己方角色所在位置,就退回到前一步(空格)停下。
	while not path.is_empty() and actor.battle.is_occupied_excluding(path[path.size() - 1], actor):
		path.remove_at(path.size() - 1)

	return path

## 遠程攻擊(atk_range > 1)已經在射程內、但離目標比射程還近時,退到接近最遠射程再出手,
## 拉開跟敵人的距離、降低被近身反擊的風險;用 atk_range 當退場的停止條件,保證退完之後
## 仍在射程內,不會白白退出射程外浪費這次攻擊。近戰(atk_range<=1)沒有後退空間,略過。
## 回傳路徑,空陣列代表不需要移動。
static func plan_kite_path(actor: BattleHero, target: BattleHero, atk_range: int) -> Array[Vector2i]:
	if atk_range <= 1:
		return []
	if Util.manhattan_distance(actor.grid_pos, target.grid_pos) >= atk_range:
		return []
	return plan_path(actor, target, true, atk_range)

## 計算朝目標前進(或遠離,away=true)的下一步:優先走能縮短(或拉開)距離的主方向,
## 只有敵方角色會擋路(己方可直接穿過);若被敵方卡住,改往另一軸側移繞路(挑選能讓
## 距離更符合目的——靠近或遠離——的一側),全部候選都走不了時回傳原地(呼叫端視為
## 卡死、停止移動)。
static func _next_step(actor: BattleHero, from: Vector2i, target: BattleHero, away: bool) -> Vector2i:
	var dx := 0
	var dy := 0

	if target.grid_pos.x != from.x:
		dx = sign(target.grid_pos.x - from.x)
	elif target.grid_pos.y != from.y:
		dy = sign(target.grid_pos.y - from.y)

	if away:
		dx = -dx
		dy = -dy

	if dx == 0 and dy == 0:
		return from

	var primary := Vector2i(from.x + dx, from.y + dy)
	if _is_within_board(primary) and not _is_blocked_by_enemy(actor, primary):
		return primary

	var sidesteps: Array[Vector2i] = []
	if dx != 0:
		sidesteps.append(Vector2i(from.x, from.y - 1))
		sidesteps.append(Vector2i(from.x, from.y + 1))
	else:
		sidesteps.append(Vector2i(from.x - 1, from.y))
		sidesteps.append(Vector2i(from.x + 1, from.y))

	sidesteps.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := Util.manhattan_distance(a, target.grid_pos)
		var db := Util.manhattan_distance(b, target.grid_pos)
		return da > db if away else da < db
	)

	for c in sidesteps:
		if _is_within_board(c) and not _is_blocked_by_enemy(actor, c):
			return c

	return from

## 只有敵方(存活中)會擋路,己方角色不會阻擋移動路徑
static func _is_blocked_by_enemy(actor: BattleHero, pos: Vector2i) -> bool:
	for e in actor.enemies:
		if e.grid_pos == pos:
			return true
	return false

static func _is_within_board(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < Battle.GRID_COLS and pos.y >= 0 and pos.y < Battle.GRID_ROWS

## 是否進入攻擊範圍(以格子曼哈頓距離判定)
static func _in_range(from: Vector2i, target_pos: Vector2i, atk_range: int) -> bool:
	return Util.manhattan_distance(from, target_pos) <= atk_range

