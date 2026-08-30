class_name FamilyTreeBuilder
extends RefCounted

## 唯一入口 build(focus):不再限定 focus 是樹的頂端——沿 children(世代 +1)、parent
## (世代 -1)、mate(世代不變)三種邊做 BFS,把 focus 所在的整個連通「親族圖」全部走
## 過一輪(父母、祖父母、配偶、子女、孫子女……只要沿血緣/婚姻邊連得到都算),BFS 完
## 才把最上層那一代整體平移成世代 1(樹頂),focus 自己則落在它在整個親族圖裡實際的
## 世代——可能不是世代 1。整理成 FamilyTreeUnit 陣列——配偶配對成同一個 Unit,並接好
## parent_unit/child_units 供 Scenes/FamilyTree 畫連接線。
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

		for parent_character in current.parent:
			if not generation_by_character.has(parent_character):
				generation_by_character[parent_character] = current_generation - 1
				queue.push_back(parent_character)

	## BFS 算出來的世代是「相對 focus(=0)」的值,可能是負數(祖先);往上追出來的
	## 最上層那一代要變成世代 1(樹頂),所以整體減去最小值再 +1 平移。
	var min_generation := 0
	for character: Character in generation_by_character:
		min_generation = mini(min_generation, int(generation_by_character[character]))

	var unit_by_character: Dictionary = {}
	var units: Array[FamilyTreeUnit] = []

	for character: Character in generation_by_character:
		if unit_by_character.has(character):
			continue

		var unit := FamilyTreeUnit.new()
		unit.primary = character
		unit.generation = int(generation_by_character[character]) - min_generation + 1
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


## 家族統計:總成員數(含配偶,不論是否在小隊裡)——CharacterDetailView 家族分頁的
## 家族旗幟區塊、Scenes/FamilyTree 頂部橫幅共用同一份計算,不要各自遍歷 units 累加。
static func count_members(units: Array[FamilyTreeUnit]) -> int:
	var count := 0
	for unit in units:
		count += 1
		if unit.partner != null:
			count += 1
	return count


## 家族統計:整個祖譜連通圖裡最高的稱謂(GameEnums.RankType,見 Character.title_rank/
## NobleTitleRule),同上共用,刻意包含不在小隊裡的配偶。
static func highest_title_rank(units: Array[FamilyTreeUnit]) -> int:
	var highest := GameEnums.RankType.F
	for unit in units:
		highest = maxi(highest, unit.primary.title_rank)
		if unit.partner != null:
			highest = maxi(highest, unit.partner.title_rank)
	return highest


## 家族統計:整個祖譜連通圖裡還在世(is_dead == false)的成員數,搭配 count_members()
## 在橫幅顯示「還在世的 / 全部」。
static func count_alive_members(units: Array[FamilyTreeUnit]) -> int:
	var count := 0
	for unit in units:
		if not unit.primary.is_dead:
			count += 1
		if unit.partner != null and not unit.partner.is_dead:
			count += 1
	return count


## 家族統計:主血統——每個成員各自百分比最高的血統項目(Bloodline.get_nonzero_entries()
## 排序後第一筆)出現次數最多的那一種(例如「龍血」「龍高血」),用來代表整個家族的血統
## 傾向。沒有任何成員帶血統資料時回傳空字串,呼叫端自行決定要不要顯示這一行。
static func dominant_bloodline_label(units: Array[FamilyTreeUnit]) -> String:
	var counts: Dictionary = {}
	var labels: Dictionary = {}
	var order: Array[String] = []

	var tally := func(character: Character) -> void:
		if character.bloodline == null:
			return
		var entries := character.bloodline.get_nonzero_entries()
		if entries.is_empty():
			return
		var top: Dictionary = entries[0]
		var key := "%d_%d" % [top["nation"], top["rank"]]
		if not counts.has(key):
			counts[key] = 0
			labels[key] = GameEnums.bloodline_full_label(top["nation"], top["rank"])
			order.append(key)
		counts[key] += 1

	for unit in units:
		tally.call(unit.primary)
		if unit.partner != null:
			tally.call(unit.partner)

	if order.is_empty():
		return ""

	var best_key: String = order[0]
	for key in order:
		if counts[key] > counts[best_key]:
			best_key = key

	return labels[best_key]
