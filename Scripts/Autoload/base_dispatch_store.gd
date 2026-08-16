extends Node

# =========================================================
# 根據地「哪棟建築派了哪個角色」的派遣紀錄(autoload,見 project.godot)。跟
# BaseResourceStore 同一套慣例:session 狀態放這裡,不放 System/。一棟建築最多派 1 位
# 角色、一位角色同一時間只能派 1 棟建築,靠 dispatch() 內先呼叫 undispatch_character()
# 清掉舊指派來保證。
#
# _ready() 向 WorldTimeStore.controller 註冊每日結算(見 CLAUDE.md「世界時間」):這支
# autoload 是 Node、應用程式全程存活,直接傳裸方法參照給 register_day_event() 不會踩
# System/time/world_time_controller.gd 開頭提到的 RefCounted 生命週期陷阱(那是
# RefCounted 事件物件才會遇到的問題)。
# =========================================================

var _assignments: Dictionary = {}


func _ready() -> void:
	WorldTimeStore.controller.register_day_event(_on_day_passed)


func dispatch(building_id: String, character_id: String) -> void:
	undispatch_character(character_id)
	_assignments[building_id] = character_id


func undispatch(building_id: String) -> void:
	_assignments.erase(building_id)


func undispatch_character(character_id: String) -> void:
	for building_id in _assignments.keys():
		if _assignments[building_id] == character_id:
			_assignments.erase(building_id)


func get_dispatched_character_id(building_id: String) -> String:
	return _assignments.get(building_id, "")


## 給 Scenes/Base/base_action_panel.gd 顯示派遣中角色名稱用,查不到(character_id 是
## 空字串,或角色已從 AllCharacterStore 移除)回傳 null。
func get_dispatched_character(building_id: String) -> Character:
	return find_character(get_dispatched_character_id(building_id))


func is_character_dispatched(character_id: String) -> bool:
	return _assignments.values().has(character_id)


func find_character(character_id: String) -> Character:
	for character in AllCharacterStore.all_characteres:
		if character.id == character_id:
			return character
	return null


func _on_day_passed() -> void:
	for building in BuildingLibrary.get_all():
		if not building.is_production_building():
			continue
		var character_id := get_dispatched_character_id(building.id)
		if character_id == "":
			continue
		var character := find_character(character_id)
		if character == null or character.is_disabled:
			continue
		if not building.consumes.is_empty():
			if not BaseResourceStore.can_afford(building.consumes):
				continue
			BaseResourceStore.spend(building.consumes)
		var daily_yield := BaseProduction.compute_daily_yield(building, character)
		BaseResourceStore.add(building.produces, daily_yield)
