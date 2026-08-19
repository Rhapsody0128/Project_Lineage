class_name BaseProduction
extends RefCounted

## 根據地生產類建築的每月產出公式:基礎產量 + 派遣角色對應素質值的加成(素質越高
## 派遣過去產出越好,不用另外開科技系統就能反映角色差異),再乘上建築等級對應的效率
## 加成——一棟建築可以同時派多位角色(容量見 BaseBuildingProgressStore.get_max_workers()),
## 逐一計算後加總即為整棟建築當月產出。

## 建築等級效率乘數,rank 是 GameEnums.RankType(0=F...8=SSS),每高一級 +10%。先簡單做,
## 之後要調難度曲線直接改這個公式或改成查表。
static func efficiency_multiplier(rank: int) -> float:
	return 1.0 + 0.1 * rank


static func compute_monthly_yield_for_worker(building: Building, character: Character, rank: int) -> int:
	if character == null:
		return 0
	var attribute_value := character.get_potential(building.potential_type)
	var base := building.base_yield + int(attribute_value / 20.0)
	return int(base * efficiency_multiplier(rank))


static func compute_monthly_yield(building: Building, characters: Array[Character], rank: int) -> int:
	var total := 0
	for character in characters:
		total += compute_monthly_yield_for_worker(building, character, rank)
	return total
