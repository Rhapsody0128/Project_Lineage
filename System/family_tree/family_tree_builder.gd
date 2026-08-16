class_name FamilyTreeBuilder
extends RefCounted

## 唯一入口 build(focus):focus 角色永遠是世代 1(樹的頂端),只沿 children/mate 兩種
## 邊往下擴散做世代 BFS(走 children 邊世代 +1、走 mate 邊世代不變)——不追 parent
## 邊,祖譜線一律只往下長,不會往上長出 focus 的祖先,才不會因為雙親兩側血緣深淺不一
## (例如一邊是初始角色沒有記錄祖先、另一邊往上還有好幾代)讓樹在中途冒出斷頭的
## 孤立節點,看起來像同時往上又往下分裂。走完 focus 所在的整個連通「子孫圖」後,
## 整理成 FamilyTreeUnit 陣列——配偶配對成同一個 Unit,並接好 parent_unit/
## child_units 供 Scenes/FamilyTree 畫連接線。
##
## 已知限制:若某個子孫的配偶本身也是樹內已出現的血親(表親聯姻),理論上會有兩條
## 血親線可以連到上一代——這裡只認 _find_parent_unit() 第一個找到的,不畫第二條線,
## 避免變成非樹狀的蜘蛛網(遊戲企劃設定總整理.md 二十三節已列為已知的未來問題,
## 不在這次範圍內解決)。

static func build(focus: Character) -> Array[FamilyTreeUnit]:
	var generation_by_character: Dictionary = {}
	var queue: Array[Character] = [focus]
	generation_by_character[focus] = 0

	while not queue.is_empty():
		var current: Character = queue.pop_front()
		var current_generation: int = generation_by_character[current]

		if current.mate != null and not generation_by_character.has(current.mate):
			generation_by_character[current.mate] = current_generation
			queue.push_back(current.mate)

		for child_character in current.children:
			if not generation_by_character.has(child_character):
				generation_by_character[child_character] = current_generation + 1
				queue.push_back(child_character)

	var unit_by_character: Dictionary = {}
	var units: Array[FamilyTreeUnit] = []

	for character: Character in generation_by_character:
		if unit_by_character.has(character):
			continue

		var unit := FamilyTreeUnit.new()
		unit.primary = character
		unit.generation = int(generation_by_character[character]) + 1
		unit_by_character[character] = unit

		var mate := character.mate
		if mate != null and generation_by_character.has(mate) and not unit_by_character.has(mate):
			unit.partner = mate
			unit_by_character[mate] = unit

		units.append(unit)

	for unit in units:
		var parent_unit: FamilyTreeUnit = _find_parent_unit(unit.primary, unit_by_character)
		if parent_unit == null and unit.partner != null:
			parent_unit = _find_parent_unit(unit.partner, unit_by_character)
		unit.parent_unit = parent_unit
		if parent_unit != null:
			parent_unit.child_units.append(unit)

	return units


static func _find_parent_unit(character: Character, unit_by_character: Dictionary) -> FamilyTreeUnit:
	for parent_character in character.parent:
		if unit_by_character.has(parent_character):
			return unit_by_character[parent_character]
	return null
