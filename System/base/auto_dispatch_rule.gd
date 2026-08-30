class_name AutoDispatchRule
extends RefCounted

## 根據地「自動派遣」規則:把目前完全閒置的角色(未停權、沒派駐任何建築、沒歷練中/待
## 確認歸隊、沒編入任何小隊——排除小隊成員是刻意的,避免自動把玩家排好的小隊成員抽走去
## 做工,見 CLAUDE.md 這次需求)依建築所需素質(potential_type)由高到低排序,依序填滿
## 指定建築的空缺工作格。
##
## auto_dispatch() 給單棟建築用(Scenes/Base/base_action_panel.gd 標題列的「自動派遣」
## 鈕);auto_dispatch_all() 給根據地整體用(Scenes/Base/base.gd 的「全部派遣」鈕),依
## BuildingLibrary.get_all() 的固定順序(已按產出難易度由易到難排列,見
## GameEnums.BuildingType 開頭註解)逐棟呼叫 auto_dispatch()——因為
## BaseDispatchStore.dispatch() 會立即寫回派遣紀錄,下一棟建築重新查詢到的閒置人力自然
## 排除掉前一棟剛佔用的人,不需要額外傳遞候選池狀態,人力不夠時基礎易產的建築優先分配到人。


static func auto_dispatch(building: Building) -> void:
	var empty_slots := BaseBuildingProgressStore.get_max_workers(building.type) - BaseDispatchStore.get_dispatched_character_ids(building.type).size()
	if empty_slots <= 0:
		return

	var sort_filter := CharacterSortFilter.new()
	sort_filter.sort_key = 3 + building.potential_type
	var candidates := sort_filter.apply(_idle_candidates())

	for i in range(mini(empty_slots, candidates.size())):
		BaseDispatchStore.dispatch(building.type, candidates[i].id)


static func auto_dispatch_all() -> void:
	for building in BuildingLibrary.get_all():
		if not building.is_production_building():
			continue
		if not BaseBuildingProgressStore.is_unlocked(building.type):
			continue
		auto_dispatch(building)


static func recall_all() -> void:
	for building in BuildingLibrary.get_all():
		if not building.is_production_building():
			continue
		for character_id in BaseDispatchStore.get_dispatched_character_ids(building.type):
			BaseDispatchStore.undispatch(building.type, character_id)


static func _idle_candidates() -> Array[Character]:
	var idle: Array[Character] = []
	for character in CharacterRosterStore.all_characteres:
		if character.is_disabled:
			continue
		if BaseDispatchStore.get_dispatched_building_type(character.id) != -1:
			continue
		if BarracksExpeditionStore.is_on_expedition(character.id) or BarracksExpeditionStore.is_awaiting_collection(character.id):
			continue
		if PartyStore.party != null and PartyStore.party.characteres.has(character):
			continue
		idle.append(character)
	return idle
