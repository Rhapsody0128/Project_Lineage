class_name BaseAltar
extends RefCounted

## 祭壇/禁忌祭壇購買奧義的花費表(見「根據地內政系統設計」文件七節)——依 Rank(F~SSS,
## 對應建築等級 1~9)查,Rank 越高單價越貴、買到的使用次數越少。祭壇消耗信仰、禁忌祭壇
## 消耗詛咒,金額共用同一張表(呼叫端直接用 Building.produces 當消耗資源,兩棟建築不用
## 另外分流)。

const COST_BY_RANK: Array[int] = [15, 25, 40, 60, 90, 130, 180, 250, 350]


static func cost_for_rank(rank: GameEnums.RankType) -> int:
	return COST_BY_RANK[clampi(rank, 0, COST_BY_RANK.size() - 1)]
