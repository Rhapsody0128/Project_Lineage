class_name WarBattleRankRule
extends RefCounted

## 單一 WarBattle(地圖上的戰場物件)的強度規則,取代已移除的「戰爭規模」(WarScale)——
## 每個戰場各自獨立骰 GameEnums.RankType(F~SSS,九級),不再由戰爭整體的規模決定,呼應
## 「戰爭就是戰爭,強弱由戰場 RANK 定義」。全部是預留位置數值,比照
## PartyController.RANK_LEVEL_RANGE 之後直接調表即可。

## 結算前最長月數,索引對應 RankType(F~SSS)。F~C 最快(1 個月)、B~A 居中(2 個月)、
## S~SSS 最久(3 個月),呼應「小戰場快、高難戰場久」。
const MAX_DURATION_MONTHS_BY_RANK: Array[int] = [1, 1, 1, 1, 2, 2, 3, 3, 3]

## 新戰場生成時,以 War.battle_power_a/b(國家戰力基準)為底乘上這個係數當這場戰場的起始
## 戰力——RANK 越高代表雙方投入越多兵力在這裡交鋒。索引對應 RankType。
const INITIAL_POWER_MULTIPLIER_BY_RANK: Array[float] = [0.3, 0.4, 0.5, 0.65, 0.8, 0.95, 1.1, 1.25, 1.4]


## 戰場 RANK 完全均勻隨機,不受戰爭本身任何數值影響(WarTension 只決定「要不要開戰」,
## 見 WarDiplomacyAi,不影響戰場強弱)。
static func pick_random_rank() -> int:
	return Util.get_random_enum_value(GameEnums.RankType)


static func max_duration_months(rank_type: int) -> int:
	return MAX_DURATION_MONTHS_BY_RANK[rank_type]


static func initial_power_multiplier(rank_type: int) -> float:
	return INITIAL_POWER_MULTIPLIER_BY_RANK[rank_type]
