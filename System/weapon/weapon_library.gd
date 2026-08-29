class_name WeaponLibrary
extends RefCounted

## 鐵匠鋪打造一把武器要花的鐵礦(GameEnums.ResourceType.ORE),調參集中在這一個常數。
const CRAFT_ORE_COST := 5

## 依 rank 抽點次數範圍(F=1~2...SSS=9~10),index 對應 GameEnums.RankType,寫法比照
## PartyController.RANK_LEVEL_RANGE——數值全部集中在這一個常數表方便之後調參。
const ROLL_COUNT_RANGE: Array[Vector2i] = [
	Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 4), Vector2i(4, 5), Vector2i(5, 6),
	Vector2i(6, 7), Vector2i(7, 8), Vector2i(8, 9), Vector2i(9, 10),
]

const MIN_POINTS_PER_ROLL := 1
const MAX_POINTS_PER_ROLL := 5
## 每次抽點骰中武器主屬性(GameEnums.weapon_main_stat())的機率相對權重提高多少
const MAIN_STAT_WEIGHT_BONUS := 2

## 直接依指定 rank_type 抽出一把武器(不經 RankDrawTable):抽點次數依 ROLL_COUNT_RANGE
## 骰一個次數,每次骰一種素質(武器主屬性權重 +30%)、加 1~5 點,同一素質可被抽中多次疊加。
static func generate_random_weapon(weapon_type: int, rank_type: int) -> WeaponInstance:
	var roll_range := ROLL_COUNT_RANGE[rank_type]
	var roll_count := Util.get_random_int(roll_range.x, roll_range.y + 1)
	var stat_points: Dictionary = {}
	for i in range(roll_count):
		var potential_type := _roll_stat_type(weapon_type)
		var points := Util.get_random_int(MIN_POINTS_PER_ROLL, MAX_POINTS_PER_ROLL + 1)
		stat_points[potential_type] = stat_points.get(potential_type, 0) + points
	return WeaponInstance.new(weapon_type, rank_type, stat_points)

## 鐵匠鋪打造入口:base_rank(鐵匠鋪目前建築等級對應的 RankType)丟進 RankDrawTable 抽出
## 實際 rank,再依實際 rank 抽點——基準值→實際值的偏移只在打造時發生,敵人配武不套用這層。
static func craft_weapon(weapon_type: int, base_rank: int) -> WeaponInstance:
	var rolled_rank := RankDrawTable.roll(base_rank)
	return generate_random_weapon(weapon_type, rolled_rank)

## 鐵匠鋪「變更武器」畫面用:幫角色把手持武器類型換成另一種。只換武器類型,**不**動
## `skill_list`——`SkillController.get_random_initial_skill_list()` 是「創角色從 0 給
## 技能」專用的抽選函式,跟變更武器是兩件事,遊戲內操作換武器不應該連帶重骰/清空角色已學
## 的技能(即使因此帶著對不上新武器的 bind_weapon 技能,`can_use_skill()` 擋用即可,不代表
## 要洗掉)。換完立刻呼叫 WeaponStore.sync_character() 讓新類型目前的全域素質加成馬上生效。
static func change_weapon_type(character: Character, new_weapon_type: int) -> void:
	character.weapon = new_weapon_type
	WeaponStore.sync_character(character)

## 加權骰選一個 GameEnums.PotentialType,寫法比照 RankDrawTable.roll() 的加權迴圈——
## 不能用 Util.get_random_chance_item(),它的回傳型別鎖死 String,跟這裡的 int key 不合。
static func _roll_stat_type(weapon_type: int) -> int:
	var main_stat := GameEnums.weapon_main_stat(weapon_type)
	var potential_types: Array = GameEnums.PotentialType.values()
	var weights: Array[float] = []
	var total := 0.0
	for potential_type in potential_types:
		var weight := 1.0 + MAIN_STAT_WEIGHT_BONUS if potential_type == main_stat else 1.0
		weights.append(weight)
		total += weight
	var picked := Util.get_random_float(0.0, total)
	var remaining := picked
	for i in range(weights.size()):
		remaining -= weights[i]
		if remaining <= 0:
			return potential_types[i]
	return potential_types[-1]
