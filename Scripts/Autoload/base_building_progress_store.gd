extends Node

# =========================================================
# 根據地「每棟建築目前等級」(autoload,見 project.godot)。跟 BaseResourceStore/
# BaseDispatchStore 同一套慣例:這是 Scenes 層的 session 狀態(玩家目前進度),不是規則
# 邏輯——規則(升級要花多少、容量怎麼算)集中在這裡的存取方法,實際耗材數字在
# Building.upgrade_costs(見 System/base/building/building_library.gd)。
#
# 等級 0 表示尚未解鎖(DISABLED,查不到 id 時的預設值),1~9 對應 GameEnums.RankType
# 的 F~SSS。容納工作角色人數 = 等級本身,不用另開容量表——升級同時解決「解鎖」跟
# 「開更多工作名額」兩件事。
# =========================================================

signal changed

var _levels: Dictionary = {}


func get_level(building_id: String) -> int:
	return _levels.get(building_id, 0)


func is_unlocked(building_id: String) -> bool:
	return get_level(building_id) > 0


func get_max_workers(building_id: String) -> int:
	return get_level(building_id)


## 回傳 GameEnums.RankType,0 級(尚未解鎖)回傳 -1,呼叫端要先用 is_unlocked() 判斷。
func get_rank(building_id: String) -> int:
	return get_level(building_id) - 1


func can_upgrade(building: Building) -> bool:
	return get_level(building.id) < building.max_level()


## can_upgrade() 為 false(已滿級)回傳空字典。
func get_upgrade_cost(building: Building) -> Dictionary:
	if not can_upgrade(building):
		return {}
	return building.upgrade_costs[get_level(building.id)]


## 資材不足或已滿級都回傳 false 且不扣款,呼叫端(BaseActionPanel)用回傳值決定要不要
## 顯示「資材不足」提示。
func upgrade(building: Building) -> bool:
	if not can_upgrade(building):
		return false
	var cost := get_upgrade_cost(building)
	if not BaseResourceStore.can_afford(cost):
		return false
	BaseResourceStore.spend(cost)
	_levels[building.id] = get_level(building.id) + 1
	changed.emit()
	return true
