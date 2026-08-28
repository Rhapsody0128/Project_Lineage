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


## RankType(F~SSS,9 級)三等分成低/中/高三個頻段:FED、CBA、S~SSS。
const BAND_SIZE := 3
## 頻段權重表:列 = 好感度換算出的基準頻段,欄 = 實際骰出的頻段。用途:避免地圖上某國
## 好感度衝高(或維持低檔)後,該國周邊遊蕩敵人整批變成同一頻段——刻意保留另外兩個頻段
## 的機率,讓 FED/CBA/S~SSS 三個頻段的敵人能穩定同場出現,不會隨好感度推進而互相取代。
## 見 System/map/roaming_enemy_spawner.gd 的呼叫端。
const BAND_WEIGHTS: Array[Array] = [
	[60.0, 30.0, 10.0],  # 基準頻段 FED
	[25.0, 50.0, 25.0],  # 基準頻段 CBA
	[10.0, 30.0, 60.0],  # 基準頻段 S~SSS
]


## 依好感度換算出的基準評級,先依 BAND_WEIGHTS 骰出落在哪個頻段,頻段內再均勻骰一個
## 具體評級——維持地圖上三個頻段同時存在,不是直接回傳 rank_for_favor() 那個單一評級。
static func scattered_rank_for_favor(favor: int) -> int:
	var base_band := rank_for_favor(favor) / BAND_SIZE
	var weights := BAND_WEIGHTS[base_band]
	var total := 0.0
	for weight in weights:
		total += weight
	var remaining := Util.get_random_float(0.0, total)
	var picked_band := weights.size() - 1
	for i in range(weights.size()):
		remaining -= weights[i]
		if remaining <= 0:
			picked_band = i
			break
	return picked_band * BAND_SIZE + Util.get_random_int(0, BAND_SIZE)
