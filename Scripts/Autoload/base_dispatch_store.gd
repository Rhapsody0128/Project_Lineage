extends Node

# =========================================================
# 根據地「哪棟建築派了哪些角色」的派遣紀錄(autoload,見 project.godot)。跟
# BaseResourceStore 同一套慣例:session 狀態放這裡,不放 System/。一棟建築最多派
# BaseBuildingProgressStore.get_max_workers() 位角色(容量=建築等級)、一位角色同一時間
# 只能派 1 棟建築,靠 dispatch() 內先呼叫 undispatch_character() 清掉舊指派來保證。
#
# 用 GameEnums.BuildingType(Building.type)當 key,不是字串——17 種建築類型本來就
# 一一對應,不需要另外維護一份 id,見 System/base/building/building.gd 開頭註解。
#
# _ready() 向 WorldTimeStore.controller 註冊每月結算(見 CLAUDE.md「世界時間」):這支
# autoload 是 Node、應用程式全程存活,直接傳裸方法參照給 register_month_event() 不會踩
# System/time/world_time_controller.gd 開頭提到的 RefCounted 生命週期陷阱(那是
# RefCounted 事件物件才會遇到的問題)。
# =========================================================

var _assignments: Dictionary = {}


func _ready() -> void:
	WorldTimeStore.controller.register_month_event(_on_month_passed)


## 建築未解鎖(0 級)、名額已滿、或角色目前已編入小隊都回傳 false 且不指派,呼叫端
## (Scenes/Base/base_action_panel.gd)用回傳值決定要不要顯示提示。跟 PartyEditGrid.place()
## 互為對稱防線——已編入小隊的角色不能再派去根據地生產,反之亦然(見 CLAUDE.md 這次
## 新增的互斥規則)。
func dispatch(building_type: GameEnums.BuildingType, character_id: String) -> bool:
	if PartyStore.party != null:
		for character in PartyStore.party.characteres:
			if character.id == character_id:
				return false
	undispatch_character(character_id)
	var current: Array = _assignments.get(building_type, [])
	if current.size() >= BaseBuildingProgressStore.get_max_workers(building_type):
		return false
	current.append(character_id)
	_assignments[building_type] = current
	return true


## 一棟建築現在可能同時有多人派駐,召回要指定是哪一位。
func undispatch(building_type: GameEnums.BuildingType, character_id: String) -> void:
	var current: Array = _assignments.get(building_type, [])
	current.erase(character_id)
	_assignments[building_type] = current


func undispatch_character(character_id: String) -> void:
	for building_type in _assignments.keys():
		var current: Array = _assignments[building_type]
		current.erase(character_id)


func get_dispatched_character_ids(building_type: GameEnums.BuildingType) -> Array[String]:
	var ids: Array[String] = []
	ids.assign(_assignments.get(building_type, []))
	return ids


## 給 Scenes/Base/base_action_panel.gd 顯示派遣中角色清單用,查不到的 id(角色已從
## AllCharacterStore 移除)直接跳過不塞 null。
func get_dispatched_characters(building_type: GameEnums.BuildingType) -> Array[Character]:
	var characters: Array[Character] = []
	for character_id in get_dispatched_character_ids(building_type):
		var character := find_character(character_id)
		if character != null:
			characters.append(character)
	return characters


func is_character_dispatched(character_id: String) -> bool:
	for building_type in _assignments:
		if (_assignments[building_type] as Array).has(character_id):
			return true
	return false


## 查角色目前派駐哪一棟建築,查不到回傳 -1(見 CharacterStatusRule.get_status_label()
## 要組「在OOO工作」的顯示文字)。
func get_dispatched_building_type(character_id: String) -> int:
	for building_type in _assignments:
		if (_assignments[building_type] as Array).has(character_id):
			return building_type
	return -1


func to_save_data() -> Dictionary:
	return SaveDataCodec.int_keyed_to_str(_assignments)


func load_save_data(data: Dictionary) -> void:
	_assignments = SaveDataCodec.str_keyed_to_int(data)


func find_character(character_id: String) -> Character:
	for character in AllCharacterStore.all_characteres:
		if character.id == character_id:
			return character
	return null


## 依建築目前生效的配方把理論產出換算成實際產出:工匠坊看 WorkshopRecipeStore 目前選定
## 的三選一配方,其餘 6 棟高階內政建築(採石場/採礦場/黑市/抄書院/科學研究所/禁忌祭壇)
## 看 Building.fixed_recipe,兩者都交給 WorkshopProduction.resolve() 統一換算——原料不足
## 時整個月不生產、不消耗(all-or-nothing,見該檔案)。其餘 5 棟不吃資源的建築
## fixed_recipe 是 null,直接原樣回傳理論產出、不消耗。
func _resolve_recipe(building: Building, theoretical_output: int) -> Dictionary:
	var recipe: WorkshopRecipe = (
		WorkshopRecipeStore.get_selected() if building.type == GameEnums.BuildingType.WORKSHOP
		else building.fixed_recipe
	)
	if recipe == null:
		return {"output": theoretical_output, "consumed": {}}
	var available: Dictionary = {}
	for resource_type in recipe.inputs:
		available[resource_type] = BaseResourceStore.get_amount(resource_type)
	return WorkshopProduction.resolve(recipe, theoretical_output, available)


## 預覽「如果現在跨過月結算」每種資源的淨變動量(配方消耗/all-or-nothing 判定已套用),
## 供 Scripts/UI/header_bar.gd 的「詳細」面板顯示下月預估增減量用——算法跟
## _on_month_passed() 一致,但不真的扣款/加值,純預覽。
func get_projected_monthly_delta() -> Dictionary:
	var delta: Dictionary = {}
	for building in BuildingLibrary.get_all():
		if not building.is_production_building():
			continue
		if not BaseBuildingProgressStore.is_unlocked(building.type):
			continue
		if not BaseBuildingProgressStore.is_active(building.type):
			continue
		var characters: Array[Character] = get_dispatched_characters(building.type).filter(
			func(character: Character) -> bool: return not character.is_disabled
		)
		if characters.is_empty():
			continue
		var level := BaseBuildingProgressStore.get_level(building.type)
		var theoretical_output := BaseProduction.compute_monthly_yield(building, characters, level)
		var result := _resolve_recipe(building, theoretical_output)
		delta[building.produces] = delta.get(building.produces, 0) + result.output
		for resource_type in result.consumed:
			delta[resource_type] = delta.get(resource_type, 0) - result.consumed[resource_type]
	return delta


func _on_month_passed() -> void:
	for building in BuildingLibrary.get_all():
		if not building.is_production_building():
			continue
		if not BaseBuildingProgressStore.is_unlocked(building.type):
			continue
		if not BaseBuildingProgressStore.is_active(building.type):
			continue
		var characters: Array[Character] = get_dispatched_characters(building.type).filter(
			func(character: Character) -> bool: return not character.is_disabled
		)
		if characters.is_empty():
			continue
		var level := BaseBuildingProgressStore.get_level(building.type)
		var theoretical_output := BaseProduction.compute_monthly_yield(building, characters, level)
		var result := _resolve_recipe(building, theoretical_output)
		BaseResourceStore.spend(result.consumed)
		BaseResourceStore.add(building.produces, result.output)
		var rank := BaseBuildingProgressStore.get_rank(building.type)
		var exp_amount := BattleReward.exp_for_dispatch(rank)
		for character in characters:
			character.gain_exp(exp_amount)
