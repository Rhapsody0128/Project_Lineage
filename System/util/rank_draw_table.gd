class_name RankDrawTable
extends RefCounted

## 「基準評級 → 抽出評級」機率表:列 = 基準評級(例如 Party.rank_type 或玩家目前等級對應
## 的 GameEnums.RankType),欄 = 這次骰到的評級,索引皆對應 RankType(F~SSS)。每列總和
## 100,列數/欄數需跟著 RankType(目前固定 9 級)一起維護。用途:同一個基準評級底下,
## 讓「每個角色各自抽一次」而非整批套用同一個評級,抽出來的評級會集中在基準評級附近、
## 偶爾往上探一兩級,不會超過基準評級。
const TABLE: Array[Array] = [
	[100.0,  0.0,  0.0,  0.0,  0.0,  0.0,  0.0,  0.0,  0.0], # F
	[ 70.0, 30.0,  0.0,  0.0,  0.0,  0.0,  0.0,  0.0,  0.0], # E
	[ 45.0, 35.0, 20.0,  0.0,  0.0,  0.0,  0.0,  0.0,  0.0], # D
	[ 30.0, 35.0, 25.0, 10.0,  0.0,  0.0,  0.0,  0.0,  0.0], # C
	[ 15.0, 25.0, 30.0, 20.0, 10.0,  0.0,  0.0,  0.0,  0.0], # B
	[  5.0, 15.0, 25.0, 30.0, 20.0,  5.0,  0.0,  0.0,  0.0], # A
	[  0.0,  5.0, 10.0, 20.0, 25.0, 25.0, 15.0,  0.0,  0.0], # S
	[  0.0,  0.0,  5.0, 10.0, 20.0, 25.0, 25.0, 15.0,  0.0], # SS
	[  0.0,  0.0,  5.0, 10.0, 15.0, 20.0, 25.0, 15.0, 10.0], # SSS
]

## 依 base_rank(GameEnums.RankType)那一列的權重骰出一個 RankType。呼叫端要「隊伍每個
## 角色各自獨立抽一次」的話,對隊上每個角色各別呼叫一次,不要只呼叫一次套用給整隊。
static func roll(base_rank: int) -> int:
	var weights := TABLE[base_rank]
	var total := 0.0
	for weight in weights:
		total += weight
	var picked := Util.get_random_float(0.0, total)
	var remaining := picked
	for i in range(weights.size()):
		remaining -= weights[i]
		if remaining <= 0:
			return i
	return weights.size() - 1
