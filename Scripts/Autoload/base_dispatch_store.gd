extends Node

# =========================================================
# 根據地「哪棟建築派了哪些角色」的派遣紀錄(autoload,見 project.godot)。跟
# BaseResourceStore 同一套慣例:session 狀態放這裡,不放 System/。一棟建築最多派
# BaseBuildingProgressStore.get_max_workers() 位角色(容量=建築等級)、一位角色同一時間
# 只能派 1 棟建築,靠 dispatch() 內先呼叫 undispatch_character() 清掉舊指派來保證。
#
# _ready() 向 WorldTimeStore.controller 註冊每月結算(見 CLAUDE.md「世界時間」):這支
# autoload 是 Node、應用程式全程存活,直接傳裸方法參照給 register_month_event() 不會踩
# System/time/world_time_controller.gd 開頭提到的 RefCounted 生命週期陷阱(那是
# RefCounted 事件物件才會遇到的問題)。
# =========================================================

var _assignments: Dictionary = {}


func _ready() -> void:
	WorldTimeStore.controller.register_month_event(_on_month_passed)


## 建築未解鎖(0 級)或名額已滿回傳 false 且不指派,呼叫端(BaseActionPanel)用回傳值
## 決定要不要顯示「已滿額」提示。
func dispatch(building_id: String, character_id: String) -> bool:
	undispatch_character(character_id)
	var current: Array = _assignments.get(building_id, [])
	if current.size() >= BaseBuildingProgressStore.get_max_workers(building_id):
		return false
	current.append(character_id)
	_assignments[building_id] = current
	return true


## 一棟建築現在可能同時有多人派駐,召回要指定是哪一位。
func undispatch(building_id: String, character_id: String) -> void:
	var current: Array = _assignments.get(building_id, [])
	current.erase(character_id)
	_assignments[building_id] = current


func undispatch_character(character_id: String) -> void:
	for building_id in _assignments.keys():
		var current: Array = _assignments[building_id]
		current.erase(character_id)


func get_dispatched_character_ids(building_id: String) -> Array[String]:
	var ids: Array[String] = []
	ids.assign(_assignments.get(building_id, []))
	return ids


## 給 Scenes/Base/base_action_panel.gd 顯示派遣中角色清單用,查不到的 id(角色已從
## AllCharacterStore 移除)直接跳過不塞 null。
func get_dispatched_characters(building_id: String) -> Array[Character]:
	var characters: Array[Character] = []
	for character_id in get_dispatched_character_ids(building_id):
		var character := find_character(character_id)
		if character != null:
			characters.append(character)
	return characters


func is_character_dispatched(character_id: String) -> bool:
	for building_id in _assignments:
		if (_assignments[building_id] as Array).has(character_id):
			return true
	return false


func find_character(character_id: String) -> Character:
	for character in AllCharacterStore.all_characteres:
		if character.id == character_id:
			return character
	return null


func _on_month_passed() -> void:
	for building in BuildingLibrary.get_all():
		if not building.is_production_building():
			continue
		if not BaseBuildingProgressStore.is_unlocked(building.id):
			continue
		var characters: Array[Character] = get_dispatched_characters(building.id).filter(
			func(character: Character) -> bool: return not character.is_disabled
		)
		if characters.is_empty():
			continue
		if not building.consumes.is_empty():
			if not BaseResourceStore.can_afford(building.consumes):
				continue
			BaseResourceStore.spend(building.consumes)
		var rank := BaseBuildingProgressStore.get_rank(building.id)
		var monthly_yield := BaseProduction.compute_monthly_yield(building, characters, rank)
		BaseResourceStore.add(building.produces, monthly_yield)
