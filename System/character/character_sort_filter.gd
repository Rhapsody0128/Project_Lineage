class_name CharacterSortFilter
extends RefCounted

# =========================================================
# 角色清單的排序/篩選邏輯,從 PartyEdit 候補清單抽出來放 System 層,
# 讓其他角色清單畫面(圖鑑、招募等)可以直接共用同一份規則,不用各自
# 兜一份 sort_custom()。畫面端只需要建立這個物件、呼叫 apply(),
# 不該自己算排序值或篩選條件。
#
# 排序只有「不排序」與「由高到低」兩種狀態(UI 用下拉選單挑排序欄位,
# 沒有低到高的需求,見 CharacterSortFilterBar)。
# =========================================================

## -1 代表不排序,其餘對應 GameEnums.CharacterSortKey
var sort_key: int = -1
## 選中的武器類型清單,空陣列代表不篩選(全部顯示)
var weapon_filter: Array = []


func apply(characteres: Array[Character]) -> Array[Character]:
	return _sort(_filter(characteres))


func _filter(characteres: Array[Character]) -> Array[Character]:
	if weapon_filter.is_empty():
		return characteres.duplicate()
	var filtered: Array[Character] = []
	for character in characteres:
		if weapon_filter.has(character.weapon):
			filtered.append(character)
	return filtered


func _sort(characteres: Array[Character]) -> Array[Character]:
	if sort_key < 0:
		return characteres
	var sorted := characteres.duplicate()
	sorted.sort_custom(func(a: Character, b: Character) -> bool:
		return _sort_value(a) > _sort_value(b)
	)
	return sorted


func _sort_value(character: Character) -> float:
	match sort_key:
		GameEnums.CharacterSortKey.LEVEL:
			return character.level_system.level
		GameEnums.CharacterSortKey.TOTAL_POTENTIAL:
			return character.strength + character.vitality + character.agility + character.dexterity + character.intelligence + character.mentality
		GameEnums.CharacterSortKey.CELL_COUNT:
			return character.battle_cost.cells.size()
		GameEnums.CharacterSortKey.STRENGTH:
			return character.strength
		GameEnums.CharacterSortKey.VITALITY:
			return character.vitality
		GameEnums.CharacterSortKey.AGILITY:
			return character.agility
		GameEnums.CharacterSortKey.DEXTERITY:
			return character.dexterity
		GameEnums.CharacterSortKey.INTELLIGENCE:
			return character.intelligence
		GameEnums.CharacterSortKey.MENTALITY:
			return character.mentality
		_:
			return 0.0


func toggle_weapon_filter(weapon_type: int) -> void:
	if weapon_filter.has(weapon_type):
		weapon_filter.erase(weapon_type)
	else:
		weapon_filter.append(weapon_type)
