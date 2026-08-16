class_name Bloodline
extends RefCounted

## 血統資料:6 國(GameEnums.BloodlineNation)x 2 階級(GameEnums.BloodlineRank)
## 共 12 個欄位,總和固定 100,以 STEP(12.5)為單位累加。索引為
## nation * RANK_COUNT + rank,見 index_of()。
const RANK_COUNT := 2
const STEP := 12.5
const TOTAL := 100.0

var percentages: Array[float]

func _init(p_percentages: Array[float]) -> void:
	percentages = p_percentages

static func index_of(nation: int, rank: int) -> int:
	return nation * RANK_COUNT + rank

func get_percentage(nation: int, rank: int) -> float:
	return percentages[index_of(nation, rank)]

## UI 用:依百分比由高到低回傳非 0 的血統項目,每項 {nation: int, rank: int, percentage: float}
func get_nonzero_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for nation in GameEnums.BloodlineNation.values():
		for rank in GameEnums.BloodlineRank.values():
			var percentage := get_percentage(nation, rank)
			if percentage > 0.0:
				entries.append({"nation": nation, "rank": rank, "percentage": percentage})
	entries.sort_custom(func(a, b): return a["percentage"] > b["percentage"])
	return entries
