extends Node

# =========================================================
# 根據地資源庫存(autoload,見 project.godot)。跟 PartyStore/MapSessionStore 同一套
# 慣例:這是 Scenes 層的 session 狀態(玩家目前存量),不是規則邏輯,規則(產量怎麼算)
# 在 System/base/base_production.gd,這裡只負責存取。
# =========================================================

## 存量變動時發出(add()/spend() 都會觸發),讓已經開著的資源 UI(例如
## HeaderBar 的資源下拉選單)能即時反映最新數字,不用等使用者關掉重開才刷新。
signal changed

var amounts: Dictionary = {}


func get_amount(resource_type: int) -> int:
	return amounts.get(resource_type, 0)


func add(resource_type: int, quantity: int) -> void:
	amounts[resource_type] = get_amount(resource_type) + quantity
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
