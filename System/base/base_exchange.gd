class_name BaseExchange
extends RefCounted

## 商隊站/黑市固定匯率兌換表(見「根據地內政系統設計」文件十/十一節,雙向版)。玩家
## 每月設定一筆自動兌換(見 Scripts/Autoload/base_exchange_store.gd),沒有每月額度
## 上限——資源不夠時當月直接不執行(不會部分兌換、不會扣成負數)。商隊站的被動生產
## (AGI→金錢)、黑市的被動生產(AGI→贓物)維持不變,這裡只管疊加在上面的兌換功能。
##
## 商隊站交易 5 種基礎資材(書本/木頭/糧食/信仰/毛皮)+ 贓物(黑市的貨幣,在這裡當一般
## 商品賣);黑市交易 5 種高階資材(科研/石材/鐵礦/詛咒/工藝品)+ 金錢(商隊站的貨幣,
## 在這裡當一般商品賣)——兩邊互相把對方的貨幣也拿來當可買賣的商品,形成金錢⇄贓物的
## 洗錢/兌現管道,12 種資源全部涵蓋,不重疊(見下方 caravan_options()/black_market_options()
## 開頭列表)。
##
## 定價方法:每種資源依「月產量基準」(12 棟生產建築的 base_yield,見
## System/base/building/building_library.gd)反比換算出一個抽象「價值點數」——月產越少
## 越稀有,單位價值越高,呼應「依產出速率給高商品價值」。工藝品(黑市)額外再加倍,反映
## 「耗費時間和資材」精製而成、價值高於單純稀缺度。Lv1 買入價 = 價值點數 ÷ 貨幣價值點數
## × BUY_MARKUP_L1(玩家多付兩成);Lv1 賣出價固定是 Lv1 買入價的一半(× SELL_RATIO_L1)
## ——同一棟建築內買了馬上賣一定虧 50%,跨兩棟建築組成的迴圈(例如金錢→贓物→金錢)也
## 因為每一步都是「买贵卖贱」而必然虧損。
##
## 價值點數對照(K=60 ÷ base_yield,四捨五入):木材5、糧食5、毛皮7、書本8、信仰9、
## 石材10、鐵礦12、金錢6、工藝品20×2=40(額外拉高)、科研30、贓物15、詛咒60。
##
## 建築等級加成:見下方 LEVEL_FAIRNESS_SHRINK 開頭註解——不是直接灌到拿到的數量上,
## 而是讓買賣價「朝公平價值比收斂」但永遠不會跨過那條線,保證不管等級多高,這些交易
## 對玩家來說都必然是虧錢的(比照 Market.gd 的 MARKUP_BY_RANK 精神)。

class ExchangeOption:
	## GameEnums.ResourceType,兌換的另一端資源(商隊站的貨幣是金錢、黑市的貨幣是贓物,
	## 見 currency_for(),不用在這裡另外存)。
	var resource: int
	## 買入(貨幣→資材):花 buy_cost 貨幣換 buy_output 個這個資源。
	var buy_cost: int
	var buy_output: int
	## 賣出(資材→貨幣):賣 sell_cost 個這個資源換 sell_output 貨幣——固定是買入匯率的
	## 一半價值,見上方類別註解。
	var sell_cost: int
	var sell_output: int

	func _init(p_resource: int, p_buy_cost: int, p_buy_output: int, p_sell_cost: int, p_sell_output: int) -> void:
		resource = p_resource
		buy_cost = p_buy_cost
		buy_output = p_buy_output
		sell_cost = p_sell_cost
		sell_output = p_sell_output


## index 0 = Lv1 ... index 8 = Lv9。舊版直接把這個數字乘在拿到的資源/貨幣數量上,結果
## 某些資源(例如毛皮)滿級後買入單價會跌破「公平價值比」(fair,見 buy_unit_price()/
## sell_unit_price()),等於玩家穩賺,不再是「买贵卖贱必虧」——已改掉。現在這個數字是
## 「收斂比例」:1.00 代表 Lv1 原始價差全部保留,數字越小代表買賣價越靠近 fair,但
## 只要 > 0 就永遠不會真正碰到 fair,買永遠比 fair 貴、賣永遠比 fair 賤。
const LEVEL_FAIRNESS_SHRINK: Array[float] = [1.00, 0.94, 0.88, 0.82, 0.75, 0.65, 0.55, 0.45, 0.35]

## Lv1 買入價相對「公平價值比」(fair)的固定加價倍率、Lv1 賣出價相對 fair 的固定折價
## 比例——用來從 ExchangeOption 手動調過的整數 buy_cost/buy_output/sell_cost/sell_output
## 反推出這個資源的 fair,見 buy_unit_price()/sell_unit_price()。
const BUY_MARKUP_L1 := 1.2
const SELL_RATIO_L1 := 0.6


## 商隊站:金錢↔5 種基礎資材 + 贓物(黑市貨幣,這裡當一般商品收購/賣出)。
static func caravan_options() -> Array[ExchangeOption]:
	return [
		ExchangeOption.new(GameEnums.ResourceType.BOOK, 8, 5, 5, 4),
		ExchangeOption.new(GameEnums.ResourceType.WOOD, 1, 1, 2, 1),
		ExchangeOption.new(GameEnums.ResourceType.FOOD, 1, 1, 2, 1),
		ExchangeOption.new(GameEnums.ResourceType.FAITH, 9, 5, 10, 9),
		ExchangeOption.new(GameEnums.ResourceType.FUR, 7, 5, 10, 7),
		ExchangeOption.new(GameEnums.ResourceType.CONTRABAND, 3, 1, 2, 3),
	]


## 黑市:贓物↔5 種高階資材 + 金錢(商隊站貨幣,這裡當一般商品收購/賣出)。工藝品刻意
## 賣得比同稀缺度的資源貴(見類別註解的加倍說明)。
static func black_market_options() -> Array[ExchangeOption]:
	return [
		ExchangeOption.new(GameEnums.ResourceType.RESEARCH, 12, 5, 5, 6),
		ExchangeOption.new(GameEnums.ResourceType.STONE, 4, 5, 5, 2),
		ExchangeOption.new(GameEnums.ResourceType.ORE, 1, 1, 2, 1),
		ExchangeOption.new(GameEnums.ResourceType.CURSE, 24, 5, 5, 12),
		ExchangeOption.new(GameEnums.ResourceType.TOOL, 16, 5, 5, 8),
		ExchangeOption.new(GameEnums.ResourceType.GOLD, 1, 2, 4, 1),
	]


static func options_for(building_type: GameEnums.BuildingType) -> Array[ExchangeOption]:
	return caravan_options() if building_type == GameEnums.BuildingType.CARAVAN else black_market_options()


static func find_option(building_type: GameEnums.BuildingType, resource: int) -> ExchangeOption:
	for option in options_for(building_type):
		if option.resource == resource:
			return option
	return null


## 商隊站的貨幣是金錢,黑市的貨幣是贓物——即該建築自己的被動產出資源(Building.produces)。
static func currency_for(building_type: GameEnums.BuildingType) -> int:
	return GameEnums.ResourceType.GOLD if building_type == GameEnums.BuildingType.CARAVAN else GameEnums.ResourceType.CONTRABAND


## 「買貴賣賤」(Lv1 賣出永遠是 Lv1 買入的一半價值)保證同一棟建築內來回兌換必虧 50%;
## 金錢↔贓物這組跨商隊站/黑市的雙向迴圈(商隊站買贓物→黑市買金錢、或反過來兩邊都賣)
## 也因為兩段各自都虧損而複合起來虧更多,不會出現無本套利無限堆疊——買賣價隨等級朝 fair
## 收斂但不會跨過(見下方兩個函式),這個「必虧」保證不管等級多高都成立。

## 買入單價(每 1 個資材要付多少貨幣)。fair 是從 Lv1 的 buy_cost/buy_output 反推出的
## 「公平價值比」(Lv1 買入價 = fair × BUY_MARKUP_L1);等級越高,實際單價越靠近 fair,
## 但 LEVEL_FAIRNESS_SHRINK 只要 > 0 就保證恆 > fair,買永遠是虧的。
static func buy_unit_price(option: ExchangeOption, level: int) -> float:
	var base := float(option.buy_cost) / float(option.buy_output)
	var fair := base / BUY_MARKUP_L1
	var shrink := LEVEL_FAIRNESS_SHRINK[clampi(level, 1, LEVEL_FAIRNESS_SHRINK.size()) - 1]
	return fair + (base - fair) * shrink


## 賣出單價(每賣 1 個資材拿到多少貨幣)。fair 同樣是從 Lv1 的 sell_cost/sell_output
## 反推(Lv1 賣出價 = fair × SELL_RATIO_L1);等級越高,實際單價越靠近 fair,但恆 < fair,
## 賣永遠是虧的。
static func sell_unit_price(option: ExchangeOption, level: int) -> float:
	var base := float(option.sell_output) / float(option.sell_cost)
	var fair := base / SELL_RATIO_L1
	var shrink := LEVEL_FAIRNESS_SHRINK[clampi(level, 1, LEVEL_FAIRNESS_SHRINK.size()) - 1]
	return fair - (fair - base) * shrink
