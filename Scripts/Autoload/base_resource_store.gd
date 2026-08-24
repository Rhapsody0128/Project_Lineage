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
## capacity 為 -1(目前只有 GOLD,見 BaseWarehouse.get_capacity())代表無上限,永遠不滿。
func is_full(resource_type: int) -> bool:
	var warehouse_level := BaseBuildingProgressStore.get_level(GameEnums.BuildingType.WAREHOUSE)
	var capacity := BaseWarehouse.get_capacity(resource_type, warehouse_level)
	return capacity >= 0 and get_amount(resource_type) >= capacity


## 超過倉庫儲存上限的部分直接捨棄(見 System/base/base_warehouse.gd),逼玩家在資源
## 快滿時去升級倉庫或花掉,而不是無腦囤積。capacity 為 -1 代表無上限(目前只有 GOLD),
## 直接累加不封頂。存量在呼叫前就已經超過上限時(例如開局預設 WOOD 300 高於未建倉庫的
## Lv0 上限 200),結果取跟目前存量的較大值,不會因為呼叫 add() 反而把既有存量砍到上限
## ——「超過上限」只代表新增的量進不去,不代表既有存量要被沒收。
func add(resource_type: int, quantity: int) -> void:
	var warehouse_level := BaseBuildingProgressStore.get_level(GameEnums.BuildingType.WAREHOUSE)
	var capacity := BaseWarehouse.get_capacity(resource_type, warehouse_level)
	var current := get_amount(resource_type)
	var new_amount := current + quantity
	amounts[resource_type] = new_amount if capacity < 0 else maxi(current, mini(new_amount, capacity))
	changed.emit()


## 倉庫還放得下多少這個資源——呼叫端(例如市集購買)可以用這個判斷「這筆數量塞不塞得下」,
## 買之前就擋下來,不要真的呼叫 add() 之後才發現多花的錢換到的資材被倉庫上限吃掉。
## 回傳 -1 代表無上限(比照 BaseWarehouse.get_capacity())。存量已經超過上限時回傳 0
## (放不下任何一點),不會是負數。
func remaining_capacity(resource_type: int) -> int:
	var warehouse_level := BaseBuildingProgressStore.get_level(GameEnums.BuildingType.WAREHOUSE)
	var capacity := BaseWarehouse.get_capacity(resource_type, warehouse_level)
	if capacity < 0:
		return -1
	return maxi(0, capacity - get_amount(resource_type))


func can_afford(costs: Dictionary) -> bool:
	for resource_type in costs:
		if get_amount(resource_type) < costs[resource_type]:
			return false
	return true


func spend(costs: Dictionary) -> void:
	for resource_type in costs:
		amounts[resource_type] = get_amount(resource_type) - costs[resource_type]
	changed.emit()


func to_save_data() -> Dictionary:
	return SaveDataCodec.int_keyed_to_str(amounts)


func load_save_data(data: Dictionary) -> void:
	amounts = SaveDataCodec.str_keyed_to_int(data)
	changed.emit()
