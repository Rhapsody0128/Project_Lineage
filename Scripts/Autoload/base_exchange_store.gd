extends Node

# =========================================================
# 商隊站/黑市「每月自動兌換」的目前設定(autoload,見 project.godot)。跟工匠坊配方
# 選擇同一種模式:玩家設定一筆方向(買入/賣出)/資源/數量(拉桿選的「單位數」),月結算
# 時自動執行一次——資源不夠就整個月不換(不會部分兌換、不會扣成負數),沒有另外的
# 每月額度上限,純粹看玩家有多少庫存。
#
# 每月結算不是自己註冊 WorldTimeController,改由 MonthlySettlementStore 統一協調(見該
# 檔案開頭註解)——外部呼叫端一律透過 settle(apply, available) 拿到的共用快照字典判斷
# 來源資源夠不夠,不直接呼叫 BaseResourceStore.can_afford(),避免跟 BaseDispatchStore/
# MoraleStore 同月搶同一份庫存時互相看到不該看到的即時異動。
# =========================================================

signal changed

## building_type -> {"is_buy": bool, "resource": int, "units": int}
var _orders: Dictionary = {}


func get_order(building_type: GameEnums.BuildingType) -> Dictionary:
	return _orders.get(building_type, {"is_buy": true, "resource": -1, "units": 0})


func set_order(building_type: GameEnums.BuildingType, is_buy: bool, resource: int, units: int) -> void:
	_orders[building_type] = {"is_buy": is_buy, "resource": resource, "units": maxi(units, 0)}
	changed.emit()


## 這個月會扣的來源資源量跟拿到的目標資源量,給 UI 預覽用,跟 _on_month_passed() 實際
## 執行的算法完全一致(共用 _resolve())。
func preview(building_type: GameEnums.BuildingType) -> Dictionary:
	return _resolve(building_type)


func _resolve(building_type: GameEnums.BuildingType) -> Dictionary:
	var empty := {"source_resource": -1, "source_amount": 0, "target_resource": -1, "target_amount": 0}
	var order := get_order(building_type)
	var units: int = order.get("units", 0)
	var resource: int = order.get("resource", -1)
	if units <= 0 or resource == -1:
		return empty

	var option := BaseExchange.find_option(building_type, resource)
	if option == null:
		return empty

	var currency := BaseExchange.currency_for(building_type)
	var multiplier := BaseExchange.get_rate_multiplier(BaseBuildingProgressStore.get_level(building_type))

	if order.get("is_buy", true):
		return {
			"source_resource": currency,
			"source_amount": option.buy_cost * units,
			"target_resource": resource,
			"target_amount": roundi(option.buy_output * units * multiplier),
		}
	return {
		"source_resource": resource,
		"source_amount": option.sell_cost * units,
		"target_resource": currency,
		"target_amount": roundi(option.sell_output * units * multiplier),
	}


func to_save_data() -> Dictionary:
	return SaveDataCodec.int_keyed_to_str(_orders)


func load_save_data(data: Dictionary) -> void:
	_orders = SaveDataCodec.str_keyed_to_int(data)
	changed.emit()


## 共用結算迴圈:`apply == true` 時真的扣款/加值(MonthlySettlementStore._run() 的
## _on_month_passed() 分支),否則只回傳淨變動量供預覽、不動 BaseResourceStore。
## `available`/`full_snapshot` 都由呼叫端(MonthlySettlementStore._run())在四支 store
## 的 settle() 都還沒呼叫之前一次補滿、貫穿整場月結算共用——來源資源夠不夠看 `available`
## 快照而非即時庫存,原因見 base_dispatch_store.gd `_resolve_recipe()` 開頭註解;目標資源
## 倉庫是否已滿看 `full_snapshot`,同一份「本月尚未動用」精神,固定不變,不會因為
## apply == true 時 BaseDispatchStore/MoraleStore 已經先動用真正的 BaseResourceStore,
## 導致同一次結算裡「滿了沒」在跑到一半時憑空翻盤,跟預覽(apply=false,BaseResourceStore
## 全程沒被動過)看到的結果對不起來。下面兩個 `if not ....has(...)` 只是給「直接單獨呼叫
## 這支 store 的 settle()」時的防呆,正常路徑一律已經補好值。
func settle(apply: bool, available: Dictionary, full_snapshot: Dictionary) -> Dictionary:
	var delta: Dictionary = {}
	for building_type in _orders.keys():
		if not BaseBuildingProgressStore.is_unlocked(building_type):
			continue
		var result := _resolve(building_type)
		if result.source_amount <= 0:
			continue
		if not available.has(result.source_resource):
			available[result.source_resource] = BaseResourceStore.get_amount(result.source_resource)
		if available[result.source_resource] < result.source_amount:
			continue
		## 目標資源倉庫已滿,這筆兌換整個月不執行(不會白白花掉來源資源)。
		if not full_snapshot.has(result.target_resource):
			full_snapshot[result.target_resource] = BaseResourceStore.is_full(result.target_resource)
		if full_snapshot[result.target_resource]:
			continue
		available[result.source_resource] -= result.source_amount
		delta[result.source_resource] = delta.get(result.source_resource, 0) - result.source_amount
		delta[result.target_resource] = delta.get(result.target_resource, 0) + result.target_amount
		if apply:
			BaseResourceStore.spend({result.source_resource: result.source_amount})
			BaseResourceStore.add(result.target_resource, result.target_amount)
	return delta
