class_name RoamingEnemySpawner
extends RefCounted

## 大地圖遊蕩敵人的生成/消失規則,持有目前所有 RoamingEnemy。整體做法:把地圖切成
## CELL_SIZE 見方的離散格子,玩家每跨進一個新格子,才對「玩家周圍 SPAWN_RADIUS 內、
## 還沒骰過的格子」各丟一次生成機率——「離散」指的是這個骰點時機(跨格才骰,不是連續
## 機率轟炸),不是敵人位置本身被格線鎖住。VISION_RADIUS(隱藏可視範圍)比 SPAWN_RADIUS
## 小,讓敵人早就已經生成在玩家視野外圍,靠近時才「冒出來」,不會整批同時彈出。
## DESPAWN_RADIUS 比 SPAWN_RADIUS 大,避免剛生成在範圍邊緣的敵人下一幀又立刻被消滅。

const CELL_SIZE := 600.0
const SPAWN_RADIUS := 2200.0
const VISION_RADIUS := 900.0
const DESPAWN_RADIUS := 3200.0
const SPAWN_CHANCE_PER_CELL := 0.35
## 避免直接生成在城堡/根據地的領土範圍內。
const MIN_DISTANCE_FROM_MAP_OBJECT := 260.0
## 玩家選擇「離開」放過某隻敵人後,要先遠離這個距離才會解除避免重觸發的保護,見
## should_skip_encounter()。比 RoamingEnemyEvent 觸發用的 ENCOUNTER_RADIUS(30)大得多,
## 否則玩家幾乎站在原地不動時,下一幀又會立刻黏著同一隻敵人重新觸發。
const DECLINED_CLEAR_RADIUS := 150.0

var enemies: Array[RoamingEnemy] = []
## Vector2i(cell) -> true,已經擲過骰的格子不再重擲,見 _spawn_around()。
var _rolled_cells: Dictionary = {}
## 剛被玩家在對話裡選「離開」放過的敵人 id——這隻敵人不會被移除(見
## RoamingEnemyEvent._build_challenge()),但玩家八成還站在牠旁邊,不能讓下一幀立刻
## 重新觸發同一場遭遇,靠 should_skip_encounter() 擋到玩家走遠。
var _declined_enemy_id: String = ""
## sentinel:確保第一次呼叫 update() 一定會跑一次生成判定。
var _last_player_cell: Vector2i = Vector2i(999999, 999999)
var _map_objects: Array[MapObject] = MapObject.get_all()


## map.gd 每幀呼叫。玩家跨到新格子才重新丟骰生成;敵人自身的遊蕩位移與離玩家太遠的
## 消失判定則每幀都要做(敵人數量少,逐一檢查很便宜)。
func update(player_pos: Vector2, delta: float) -> void:
	var cell := _cell_of(player_pos)
	if cell != _last_player_cell:
		_last_player_cell = cell
		_spawn_around(player_pos)

	for enemy in enemies:
		enemy.advance_wander(delta)

	_despawn_far(player_pos)


func is_visible_to_player(enemy: RoamingEnemy, player_pos: Vector2) -> bool:
	return enemy.position.distance_to(player_pos) <= VISION_RADIUS


## 實際開打(玩家在遭遇對話選「戰鬥」)當下呼叫,讓這隻敵人從地圖上消耗掉。選「離開」
## 不算數——那隻敵人要繼續留在地圖上,見 decline_encounter()。
func remove_enemy(enemy: RoamingEnemy) -> void:
	enemies.erase(enemy)
	_rolled_cells.erase(_cell_of(enemy.anchor))
	if _declined_enemy_id == enemy.id:
		_declined_enemy_id = ""


## 玩家在遭遇對話選「離開」時呼叫(見 RoamingEnemyEvent._build_challenge()):這隻敵人
## 不從地圖上移除,只記下 id,讓 should_skip_encounter() 暫時擋掉重觸發。
func decline_encounter(enemy: RoamingEnemy) -> void:
	_declined_enemy_id = enemy.id


## 玩家直接點擊瞄準這隻敵人再出發(見 map.gd 的 _handle_click_to_move())時呼叫:點擊
## 本身就是明確想再次交手的意圖,不必等玩家先走遠 DECLINED_CLEAR_RADIUS 才解除——否則
## 選了「離開」原地沒動又立刻點回同一隻敵人,會變成一直追著牠移動卻永遠觸發不了對話
## (should_skip_encounter() 距離判定一直沒過)。非這隻敵人時不做任何事。
func clear_declined(enemy: RoamingEnemy) -> void:
	if _declined_enemy_id == enemy.id:
		_declined_enemy_id = ""


## map.gd 的 _check_roaming_encounters() 每幀呼叫:剛被放過的那隻敵人,玩家還沒走遠
## (DECLINED_CLEAR_RADIUS 內)之前都跳過,避免同一幀/下一幀立刻又黏上去重新觸發同一場
## 對話。走遠一次之後保護就解除,之後再靠近會正常重新觸發。
func should_skip_encounter(enemy: RoamingEnemy, player_pos: Vector2) -> bool:
	if enemy.id != _declined_enemy_id:
		return false
	if enemy.position.distance_to(player_pos) > DECLINED_CLEAR_RADIUS:
		_declined_enemy_id = ""
		return false
	return true


func _cell_of(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / CELL_SIZE), floori(pos.y / CELL_SIZE))


func _spawn_around(player_pos: Vector2) -> void:
	var player_cell := _cell_of(player_pos)
	var cell_radius := ceili(SPAWN_RADIUS / CELL_SIZE)

	for dx in range(-cell_radius, cell_radius + 1):
		for dy in range(-cell_radius, cell_radius + 1):
			var cell := player_cell + Vector2i(dx, dy)
			if _rolled_cells.has(cell):
				continue

			var cell_center := Vector2((cell.x + 0.5) * CELL_SIZE, (cell.y + 0.5) * CELL_SIZE)
			if cell_center.distance_to(player_pos) > SPAWN_RADIUS:
				continue

			_rolled_cells[cell] = true
			_try_spawn_in_cell(cell)


func _try_spawn_in_cell(cell: Vector2i) -> void:
	if Util.get_random_float(0.0, 1.0) > SPAWN_CHANCE_PER_CELL:
		return

	var cell_origin := Vector2(cell.x * CELL_SIZE, cell.y * CELL_SIZE)
	var spawn_pos := Vector2(
		clamp(cell_origin.x + Util.get_random_float(0.0, CELL_SIZE), 0.0, MapSystem.MAP_SIZE.x),
		clamp(cell_origin.y + Util.get_random_float(0.0, CELL_SIZE), 0.0, MapSystem.MAP_SIZE.y)
	)

	if _is_too_close_to_map_object(spawn_pos):
		return

	var party := PartyController.get_random_party()
	var enemy := RoamingEnemy.new(Util.generate_uuid(), spawn_pos, party, GameEnums.RankType.E)
	enemies.append(enemy)


func _is_too_close_to_map_object(pos: Vector2) -> bool:
	for obj in _map_objects:
		if pos.distance_to(obj.position) < MIN_DISTANCE_FROM_MAP_OBJECT:
			return true
	return false


func _despawn_far(player_pos: Vector2) -> void:
	for i in range(enemies.size() - 1, -1, -1):
		var enemy: RoamingEnemy = enemies[i]
		if enemy.position.distance_to(player_pos) > DESPAWN_RADIUS:
			enemies.remove_at(i)
			_rolled_cells.erase(_cell_of(enemy.anchor))
