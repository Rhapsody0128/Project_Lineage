extends Node

# =========================================================
# 商隊站/黑市「每月自動兌換」的目前設定(autoload,見 project.godot)。跟工匠坊配方
# 選擇同一種模式:玩家設定一筆方向(買入/賣出)/資源/數量(拉桿選的「單位數」),月結算
# 時自動執行一次——資源不夠就整個月不換(不會部分兌換、不會扣成負數),沒有另外的
# 每月額度上限,純粹看玩家有多少庫存。
# =========================================================

signal changed

## building_type -> {"is_buy": bool, "resource": int, "units": int}
var _orders: Dictionary = {}


func _ready() -> void:
	WorldTimeStore.controller.register_month_event(_on_month_passed)


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


## 預覽「如果現在跨過月結算」這批訂單各自的淨變動量,合併規則跟 _on_month_passed()
## 一致(倉庫已滿的目標資源跳過),供 Scripts/UI/header_bar.gd 的「詳細」面板顯示下月
## 預估增減量用,純預覽、不會真的執行。
func get_projected_monthly_delta() -> Dictionary:
	var delta: Dictionary = {}
	for building_type in _orders.keys():
		if not BaseBuildingProgressStore.is_unlocked(building_type):
			continue
		var result := _resolve(building_type)
		if result.source_amount <= 0:
			continue
		if not BaseResourceStore.can_afford({result.source_resource: result.source_amount}):
			continue
		if BaseResourceStore.is_full(result.target_resource):
			continue
		delta[result.source_resource] = delta.get(result.source_resource, 0) - result.source_amount
		delta[result.target_resource] = delta.get(result.target_resource, 0) + result.target_amount
	return delta


func _on_month_passed() -> void:
	for building_type in _orders.keys():
		if not BaseBuildingProgressStore.is_unlocked(building_type):
			continue
		var result := _resolve(building_type)
		if result.source_amount <= 0:
			continue
		if not BaseResourceStore.can_afford({result.source_resource: result.source_amount}):
			continue
		## 目標資源倉庫已滿,這筆兌換整個月不執行(不會白白花掉來源資源)。
		if BaseResourceStore.is_full(result.target_resource):
			continue
		BaseResourceStore.spend({result.source_resource: result.source_amount})
		BaseResourceStore.add(result.target_resource, result.target_amount)
