class_name NationFavorRank
extends RefCounted

## 好感度數值(NationFavorStore.get_favor())換算成 GameEnums.RankType(F..SSS)等級的
## 門檻表,索引直接對應 RankType,比照 System/party/party_controller.gd 的
## RANK_LEVEL_RANGE 慣例。累積好感度是持續增長的玩家資料,查表邏輯放在 System/nation/
## 這個純規則層,實際數值仍存在 NationFavorStore(autoload)。
const THRESHOLDS: Array[int] = [0, 10, 50, 200, 500, 1000, 2500, 5000, 10000]


## 由高到低找第一個達標的門檻,回傳對應 RankType。
static func rank_for_favor(favor: int) -> int:
	for rank in range(THRESHOLDS.size() - 1, -1, -1):
		if favor >= THRESHOLDS[rank]:
			return rank
	return GameEnums.RankType.F


static func label_for_favor(favor: int) -> String:
	return GameEnums.rank_label(rank_for_favor(favor))
