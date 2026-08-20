extends Node

# =========================================================
# 根據地資源庫存(autoload,見 project.godot)。跟 PartyStore/MapSessionStore 同一套
# 慣例:這是 Scenes 層的 session 狀態(玩家目前存量),不是規則邏輯,規則(產量怎麼算)
# 在 System/base/base_production.gd,這裡只負責存取。
# =========================================================

## 存量變動時發出(add()/spend() 都會觸發),讓已經開著的資源 UI(例如
## HeaderBar 的資源下拉選單)能即時反映最新數字,不用等使用者關掉重開才刷新。
signal changed

## 玩家預設起始資源,根據地剛開局就有這些可用來建造第一批建築。
var amounts: Dictionary = {
	GameEnums.ResourceType.WOOD: 300,
	GameEnums.ResourceType.GOLD: 500,
}


func get_amount(resource_type: int) -> int:
	return amounts.get(resource_type, 0)


## 存量是否已達倉庫上限——月結算的自動兌換(見 Scripts/Autoload/base_exchange_store.gd)
## 拿這個判斷目標資源倉庫滿了就整筆跳過,不白白花掉來源資源換到會被 add() 直接捨棄的量。
func is_full(resource_type: int) -> bool:
	var warehouse_level := BaseBuildingProgressStore.get_level(GameEnums.BuildingType.WAREHOUSE)
	return get_amount(resource_type) >= BaseWarehouse.get_capacity(resource_type, warehouse_level)


## 超過倉庫儲存上限的部分直接捨棄(見 System/base/base_warehouse.gd),逼玩家在資源
## 快滿時去升級倉庫或花掉,而不是無腦囤積。
func add(resource_type: int, quantity: int) -> void:
	var warehouse_level := BaseBuildingProgressStore.get_level(GameEnums.BuildingType.WAREHOUSE)
	var capacity := BaseWarehouse.get_capacity(resource_type, warehouse_level)
	amounts[resource_type] = mini(get_amount(resource_type) + quantity, capacity)
	changed.emit()


func can_afford(costs: Dictionary) -> bool:
	for resource_type in costs:
		if get_amount(resource_type) < costs[resource_type]:
			return false
	return true


func spend(costs: Dictionary) -> void:
	for resource_type in costs:
		amounts[resource_type] = get_amount(resource_type) - costs[resource_type]
	changed.emit()
