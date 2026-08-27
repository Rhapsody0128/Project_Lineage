class_name BaseAltar
extends RefCounted

## 祭壇/禁忌祭壇購買奧義的花費表(「奧義擴充設計」章節)——依 Rank(F~SSS,對應建築
## 等級 1~9)查,Rank 越高單價越貴。祭壇消耗信仰、禁忌祭壇消耗詛咒,兩者不再共用同一張
## 表(詛咒是全遊戲最稀缺的資源,金額必須遠低於信仰,見下方換算)。
##
## 定價方法:抓「意志 130 角色、只派 1 人」在對應等級祭壇/禁忌祭壇(建築等級 = Rank
## 序位+1)的月產量(見 System/base/base_production.gd)乘以 1.8 當研發價格,再四捨五入
## 到 5 的倍數。用 1 人當預設基準,不是因為工作格只有 1 個——
## BaseBuildingProgressStore.get_max_workers() 等於建築等級,滿級最多可以塞 9 人,產量
## 會遠高於這裡的估算——而是「1 人」只當價格下限的保守基準,玩家多派人力/角色屬性更高
## 都只會讓實際產出節奏比這裡估的更快,不會卡在買不起。信仰表換算下來每個 Rank 落在月產
## 0.5~0.6 個奧義使用次數,對應「一個月生產 0.5~1 個」的目標下緣(多派人力後自然往上緣
## 靠)。詛咒表如果比照同一套 1 人基準硬算,九個 Rank 的價格四捨五入到 5 的倍數後會全部
## 收斂在 5(禁忌祭壇 base_yield 只有祭壇的 1/7,月產量太小撐不出價格差異),所以詛咒表
## 沿用「多派人力」基準(意志 130、最多派 3 人)另外估算,數字依然會在低階重複,是詛咒
## 本來就是全遊戲最稀缺資源、產量撐不出那麼細的價格階梯,不是沒算清楚。
const COST_BY_RANK_FAITH: Array[int] = [15, 20, 25, 30, 35, 45, 55, 65, 80]
const COST_BY_RANK_CURSE: Array[int] = [5, 10, 10, 15, 15, 20, 20, 25, 30]


static func cost_for_rank(rank: GameEnums.RankType, building_type: GameEnums.BuildingType) -> int:
	var table := COST_BY_RANK_CURSE if building_type == GameEnums.BuildingType.FORBIDDEN_ALTAR else COST_BY_RANK_FAITH
	return table[clampi(rank, 0, table.size() - 1)]
