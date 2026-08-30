extends Node

# =========================================================
# 商隊站/黑市「每月自動兌換」的目前設定(autoload,見 project.godot)。跟工匠坊配方
# 選擇同一種模式:玩家設定一筆方向(買入/賣出)/資源/數量(拉桿選的「資材數量」,買入時
# 是想買到的資材量、賣出時是想賣掉的資材量)——月結算時自動執行一次,資源不夠就整個月不換
# (不會部分兌換、不會扣成負數)。
#
# 每棟建築可能同時開好幾條「貿易路線」(見 System/base/base_exchange.gd 的
# route_count()/route_capacity(),「市集通商」科技線加成):每條路線各自一筆獨立訂單、
# 互不共用額度,可以同時交易不同資材。單條路線的交易量上限不是寫死的,是「該建築目前派駐
# 人數 × TRADE_UNITS_PER_ROUTE_WORKER」(BaseExchange.route_capacity()),沒派人就是 0——
# _resolve() 換算價格前一律先夾這個上限,UI 滑桿上限只是輔助顯示,玩家調完滑桿後召回角色
# 也不會讓已存的訂單繞過上限。
#
# 單價由 BaseExchange.buy_unit_price()/sell_unit_price() 依建築等級算(隨等級朝「公平
# 價值比」收斂但保證不會跨過,見該檔案開頭註解),這裡只負責「數量 × 單價」換算跟月結算
# 迴圈,不重複算價格公式。
#
# 每月結算不是自己註冊 WorldTimeController,改由 MonthlySettlementStore 統一協調(見該
# 檔案開頭註解)——外部呼叫端一律透過 settle(apply, available, remaining_capacity) 拿到的
# 共用快照字典判斷來源資源夠不夠、目標資源倉庫還放得下多少,不直接呼叫
# BaseResourceStore.can_afford()/remaining_capacity(),避免跟 BaseDispatchStore/
# MoraleStore 同月搶同一份庫存時互相看到不該看到的即時異動。
# =========================================================

signal changed

## building_type -> Array[{"is_buy": bool, "resource": int, "units": int}]——陣列索引即
## 路線編號(route_index),"units" 是拉桿選的資材數量(見上方檔頭註解),買入時代表想買到
## 的資材量、賣出時代表想賣掉的資材量。
var _orders: Dictionary = {}


func get_order(building_type: GameEnums.BuildingType, route_index: int) -> Dictionary:
	var routes: Array = _orders.get(building_type, [])
	if route_index < routes.size():
		return routes[route_index]
	return {"is_buy": true, "resource": -1, "units": 0}


func set_order(building_type: GameEnums.BuildingType, route_index: int, is_buy: bool, resource: int, units: int) -> void:
	var routes: Array = _orders.get(building_type, [])
	while routes.size() <= route_index:
		routes.append({"is_buy": true, "resource": -1, "units": 0})
	routes[route_index] = {"is_buy": is_buy, "resource": resource, "units": maxi(units, 0)}
	_orders[building_type] = routes
	changed.emit()


## 這個月會扣的來源資源量跟拿到的目標資源量,給 UI 預覽用,跟 _on_month_passed() 實際
## 執行的算法完全一致(共用 _resolve())。目標資源倉庫剩多少空間這裡改讀即時庫存(不像
## settle() 要共用固定快照)——這只是玩家調拉桿當下的即時參考,不需要跟月結算那樣保證
## apply=true/false 兩條路徑逐項比對得起來。
func preview(building_type: GameEnums.BuildingType, route_index: int) -> Dictionary:
	var order := get_order(building_type, route_index)
	if order.get("units", 0) <= 0 or order.get("resource", -1) == -1:
		return _resolve(building_type, route_index)
	var target_resource: int = (
		order.get("resource") if order.get("is_buy", true) else BaseExchange.currency_for(building_type)
	)
	return _resolve(building_type, route_index, BaseResourceStore.remaining_capacity(target_resource))


## `target_capacity` 是目標資源「還放得下多少」,-1 代表無上限(比照
## BaseResourceStore.remaining_capacity())、預設值 -1 給不需要顧慮倉庫上限的呼叫端用。
## 買入時直接把想買的數量砍到剩餘容量(數量本來就是資材量,砍完再算價錢);賣出時反過來
## 從「目標貨幣還放得下多少」反推最多能賣幾個資材,兩者都不是先算好全額再事後打折,砍下來
## 的部分不會多花錢/多耗資材——比照 WorkshopProduction.resolve() 原料不足時等比例打折
## 產出的精神。
##
## `amount` 換算價格前先夾一次「這條路線的交易量上限」(該建築目前派駐人數 × 20,見
## System/base/base_exchange.gd route_capacity())——這是真正的伺服器端防呆,UI 滑桿上限
## 只是輔助顯示,玩家調完滑桿後召回角色也不會讓已存的訂單繞過上限。
func _resolve(building_type: GameEnums.BuildingType, route_index: int, target_capacity: int = -1) -> Dictionary:
	var empty := {"source_resource": -1, "source_amount": 0, "target_resource": -1, "target_amount": 0}
	var order := get_order(building_type, route_index)
	var worker_count := BaseDispatchStore.get_dispatched_characters(building_type).size()
	var amount: int = mini(order.get("units", 0), BaseExchange.route_capacity(worker_count))
	var resource: int = order.get("resource", -1)
	if amount <= 0 or resource == -1:
		return empty

	var option := BaseExchange.find_option(building_type, resource)
	if option == null:
		return empty

	var currency := BaseExchange.currency_for(building_type)
	var level := BaseBuildingProgressStore.get_level(building_type)

	if order.get("is_buy", true):
		var target_amount := amount
		if target_capacity >= 0:
			target_amount = mini(target_amount, target_capacity)
		if target_amount <= 0:
			return empty
		var price := BaseExchange.buy_unit_price(option, level)
		return {
			"source_resource": currency,
			"source_amount": ceili(target_amount * price),
			"target_resource": resource,
			"target_amount": target_amount,
		}

	var sell_price := BaseExchange.sell_unit_price(option, level)
	var source_amount := amount
	if target_capacity >= 0 and sell_price > 0.0:
		source_amount = mini(source_amount, floori(float(target_capacity) / sell_price))
	if source_amount <= 0:
		return empty
	return {
		"source_resource": resource,
		"source_amount": source_amount,
		"target_resource": currency,
		"target_amount": floori(source_amount * sell_price),
	}


func to_save_data() -> Dictionary:
	return SaveDataCodec.int_keyed_to_str(_orders)


func load_save_data(data: Dictionary) -> void:
	_orders = SaveDataCodec.str_keyed_to_int(data)
	changed.emit()


## 共用結算迴圈:`apply == true` 時真的扣款/加值(MonthlySettlementStore._run() 的
## _on_month_passed() 分支),否則只回傳淨變動量供預覽、不動 BaseResourceStore。
## `available`/`remaining_capacity` 都由呼叫端(MonthlySettlementStore._run())在四支
## store 的 settle() 都還沒呼叫之前一次補滿、貫穿整場月結算共用——來源資源夠不夠看
## `available` 快照而非即時庫存,原因見 base_dispatch_store.gd `_resolve_recipe()` 開頭
## 註解;目標資源倉庫還放得下多少看 `remaining_capacity`,同一份「本月尚未動用」精神,
## 固定不變,不會因為 apply == true 時 BaseDispatchStore/MoraleStore 已經先動用真正的
## BaseResourceStore,導致同一次結算裡「還放得下多少」在跑到一半時憑空翻盤,跟預覽
## (apply=false,BaseResourceStore 全程沒被動過)看到的結果對不起來。下面兩個
## `if not ....has(...)` 只是給「直接單獨呼叫這支 store 的 settle()」時的防呆,正常路徑
## 一律已經補好值。
##
## 目標資源快滿倉時不再像舊版整筆整月不換(玩家花了對應整筆的錢,超過倉庫上限的部分卻被
## BaseResourceStore.add() 直接捨棄、白白浪費)——改成只買/賣到剛好塞滿倉庫的量,來源
## 花費/資材跟著等比例減少,見 _resolve() 的 target_capacity 參數。
##
## 建築暫停(BaseBuildingProgressStore.is_active() == false)時整棟跳過,不兌換——跟
## BaseDispatchStore.settle() 的既有慣例一致(玩家用 ActionPanel 標題列開關鈕關掉生產,
## 貿易路線也要一起停,不只是被動生產停)。
func settle(apply: bool, available: Dictionary, remaining_capacity: Dictionary) -> Dictionary:
	var delta: Dictionary = {}
	for building_type in _orders.keys():
		if not BaseBuildingProgressStore.is_unlocked(building_type):
			continue
		if not BaseBuildingProgressStore.is_active(building_type):
			continue
		var routes: Array = _orders[building_type]
		for route_index in range(routes.size()):
			var order: Dictionary = routes[route_index]
			if order.get("units", 0) <= 0 or order.get("resource", -1) == -1:
				continue
			var target_resource: int = (
				order.get("resource") if order.get("is_buy", true) else BaseExchange.currency_for(building_type)
			)
			if not remaining_capacity.has(target_resource):
				remaining_capacity[target_resource] = BaseResourceStore.remaining_capacity(target_resource)
			var result := _resolve(building_type, route_index, remaining_capacity[target_resource])
			if result.source_amount <= 0:
				continue
			if not available.has(result.source_resource):
				available[result.source_resource] = BaseResourceStore.get_amount(result.source_resource)
			if available[result.source_resource] < result.source_amount:
				continue
			available[result.source_resource] -= result.source_amount
			if remaining_capacity[result.target_resource] >= 0:
				remaining_capacity[result.target_resource] -= result.target_amount
			delta[result.source_resource] = delta.get(result.source_resource, 0) - result.source_amount
			delta[result.target_resource] = delta.get(result.target_resource, 0) + result.target_amount
			if apply:
				BaseResourceStore.spend({result.source_resource: result.source_amount})
				BaseResourceStore.add(result.target_resource, result.target_amount)
	return delta
