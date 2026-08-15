class_name HeroSortFilter
extends RefCounted

# =========================================================
# 角色清單的排序/篩選邏輯,從 PartyEdit 候補清單抽出來放 System 層,
# 讓其他角色清單畫面(圖鑑、招募等)可以直接共用同一份規則,不用各自
# 兜一份 sort_custom()。畫面端只需要建立這個物件、呼叫 apply(),
# 不該自己算排序值或篩選條件。
#
# 排序只有「不排序」與「由高到低」兩種狀態(UI 用下拉選單挑排序欄位,
# 沒有低到高的需求,見 HeroSortFilterBar)。
# =========================================================

## -1 代表不排序,其餘對應 GameEnums.HeroSortKey
var sort_key: int = -1
## 選中的武器類型清單,空陣列代表不篩選(全部顯示)
var weapon_filter: Array = []


func apply(heroes: Array[Hero]) -> Array[Hero]:
	return _sort(_filter(heroes))


func _filter(heroes: Array[Hero]) -> Array[Hero]:
	if weapon_filter.is_empty():
		return heroes.duplicate()
	var filtered: Array[Hero] = []
	for hero in heroes:
		if weapon_filter.has(hero.weapon):
			filtered.append(hero)
	return filtered


func _sort(heroes: Array[Hero]) -> Array[Hero]:
	if sort_key < 0:
		return heroes
	var sorted := heroes.duplicate()
	sorted.sort_custom(func(a: Hero, b: Hero) -> bool:
		return _sort_value(a) > _sort_value(b)
	)
	return sorted


func _sort_value(hero: Hero) -> float:
	match sort_key:
		GameEnums.HeroSortKey.LEVEL:
			return hero.level_system.level
		GameEnums.HeroSortKey.TOTAL_POTENTIAL:
			return hero.strength + hero.vitality + hero.agility + hero.dexterity + hero.intelligence + hero.mentality
		GameEnums.HeroSortKey.CELL_COUNT:
			return hero.battle_cost.cells.size()
		GameEnums.HeroSortKey.STRENGTH:
			return hero.strength
		GameEnums.HeroSortKey.VITALITY:
			return hero.vitality
		GameEnums.HeroSortKey.AGILITY:
			return hero.agility
		GameEnums.HeroSortKey.DEXTERITY:
			return hero.dexterity
		GameEnums.HeroSortKey.INTELLIGENCE:
			return hero.intelligence
		GameEnums.HeroSortKey.MENTALITY:
			return hero.mentality
		_:
			return 0.0


func toggle_weapon_filter(weapon_type: int) -> void:
	if weapon_filter.has(weapon_type):
		weapon_filter.erase(weapon_type)
	else:
		weapon_filter.append(weapon_type)
