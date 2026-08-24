class_name Market
extends RefCounted

## 城鎮市集(Scenes/MapLocation/market_panel_content.gd)的定價規則:玩家直接用金錢/贓物
## 跟市集買資材,不像 BaseExchange 需要蓋商隊站/黑市、每月才自動兌換一次一批,也不能賣
## 東西回市集。單價以 BaseExchange 對應資源的 Lv1 買入匯率(不套用建築等級加成的最低價)
## 當基準,乘上一個永遠 > 1.0 的加價倍率(見 MARKUP_BY_RANK),保證市集價格一定比玩家能
## 拿到的最低貿易價貴——倍率依玩家對這座城鎮所屬國家的好感度等級(F~SSS)遞減,呼應
## 「好感度提高會些微便宜一點,但還是比貿易貴」的設計。

## 索引對應 GameEnums.RankType(F..SSS,好感度等級換算見 NationFavorRank)。刻意拉到
## 「貴一截」的等級(F 級 2.2 倍、SSS 也還要 1.5 倍),不是貿易的替代品——市集買得到
## 但明顯不划算,逼玩家還是得蓋商隊站/黑市經營貿易,好感度頂多讓市集從「很貴」變
## 「還是貴」。
const MARKUP_BY_RANK: Array[float] = [2.20, 2.10, 2.00, 1.90, 1.80, 1.70, 1.60, 1.55, 1.50]


class MarketOption:
	var resource: int
	## 支付貨幣——比照 BaseExchange.currency_for():基礎資材付金錢,高階資材付贓物。
	var currency: int
	## BaseExchange 對應選項的 Lv1 單價(未套用建築等級加成),市集價格的計算基準,見
	## unit_price()。
	var base_unit_price: float

	func _init(p_resource: int, p_currency: int, p_base_unit_price: float) -> void:
		resource = p_resource
		currency = p_currency
		base_unit_price = p_base_unit_price


## 市集賣的 10 種資材:BaseExchange 的商隊站/黑市清單各自扣掉「把對方貨幣當商品買賣」
## 那一筆(商隊站的贓物、黑市的金錢是貨幣本身,不是資材,市集不賣)。
static func options() -> Array[MarketOption]:
	var result: Array[MarketOption] = []
	for option in BaseExchange.caravan_options():
		if option.resource == GameEnums.ResourceType.CONTRABAND:
			continue
		result.append(MarketOption.new(option.resource, GameEnums.ResourceType.GOLD, float(option.buy_cost) / option.buy_output))
	for option in BaseExchange.black_market_options():
		if option.resource == GameEnums.ResourceType.GOLD:
			continue
		result.append(MarketOption.new(option.resource, GameEnums.ResourceType.CONTRABAND, float(option.buy_cost) / option.buy_output))
	return result


## 無條件進位——市集價格不會因為四捨五入變得比貿易基準價還便宜。
static func unit_price(base_unit_price: float, favor_rank: int) -> int:
	var markup := MARKUP_BY_RANK[clampi(favor_rank, 0, MARKUP_BY_RANK.size() - 1)]
	return ceili(base_unit_price * markup)
