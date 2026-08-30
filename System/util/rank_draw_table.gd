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
	# -----------------------------------------------------------------
	# 以下提供給有些DRAW需要自身RANK數量+N的TABLE使用
	[  0.0,  0.0,  0.0,  5.0, 10.0, 20.0, 25.0, 25.0, 15.0], # SSS + 1
	[  0.0,  0.0,  0.0,  0.0,  5.0, 15.0, 25.0, 30.0, 25.0], # SSS + 2
	[  0.0,  0.0,  0.0,  0.0,  0.0, 10.0, 20.0, 35.0, 35.0], # SSS + 3
	[  0.0,  0.0,  0.0,  0.0,  0.0,  0.0, 15.0, 35.0, 50.0], # SSS + 4
	[  0.0,  0.0,  0.0,  0.0,  0.0,  0.0,  5.0, 25.0, 70.0], # SSS + 5
]

## base_rank 允許的最大值(對應 SSS + 5 那一列,= TABLE 列數 - 1,寫死是因為 GDScript
## const 初始化不能呼叫 Array.size())——需要疊加「自身 RANK 數量 + N」的呼叫端(例如連續
## 作戰/連續攻城的難度遞增)疊完 N 後要 clamp 在這個上限,避免疊過頭超出 TABLE 列數導致
## roll() 陣列越界;疊加當下不要提早 clamp 在 GameEnums.RankType.SSS,那樣會抹殺掉這幾列
## 「SSS + N」存在的意義。新增/刪減 TABLE 列數時要同步改這個常數。
const MAX_BASE_RANK := 13

## 依 base_rank(GameEnums.RankType,或疊加過「+N」、超出 SSS 但不超過 MAX_BASE_RANK 的值)
## 那一列的權重骰出一個 RankType。呼叫端要「隊伍每個角色各自獨立抽一次」的話,對隊上每個
## 角色各別呼叫一次,不要只呼叫一次套用給整隊。
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
