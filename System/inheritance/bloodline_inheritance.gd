class_name BloodlineInheritance
extends RefCounted

## 血統遺傳計算:父母血統逐欄取平均當理論值 → 對齊回 Bloodline.STEP(12.5)的網格
## (見 _align_to_step_grid())→ 再依 InheritanceConstants 的機率表骰一次變異
## (隨機一個欄位 +變量、另一個欄位 -變量,增減相等以確保總和仍是 100)。
##
## 對齊網格本身如果真的動到欄位,就算用掉一次「輕微變異」額度:骰到 0 沒差(本來就
## 不變異)、骰到 1(輕微變異)視為已經被對齊那次抵掉,不再額外變異;骰到 2(大變異)
## 只需要再補一次「輕微變異」(1 個 STEP),不是整整兩個 STEP,避免對齊+變異疊加成
## 比機率表原本設計還誇張的變動量。

static func inherit(father_bloodline: Bloodline, mother_bloodline: Bloodline) -> Bloodline:
	var percentages: Array[float] = []
	for i in range(father_bloodline.percentages.size()):
		percentages.append((father_bloodline.percentages[i] + mother_bloodline.percentages[i]) / 2.0)

	var alignment_used_mutation := _align_to_step_grid(percentages)

	var multiplier := int(Util.get_random_chance_item(InheritanceConstants.bloodline_mutation_chances()))
	if alignment_used_mutation:
		multiplier -= 1
	if multiplier > 0:
		_apply_mutation(percentages, multiplier * Bloodline.STEP)

	return Bloodline.new(percentages)

## 父母的每個欄位都保證是 Bloodline.STEP(12.5)的整數倍,但兩者取平均只保證落在
## 半格(6.25)網格上——例如 12.5 跟 0 平均出 6.25,不是合法的 12.5 倍數,後面
## _apply_mutation() 的整數倍運算會對不上。
##
## 做法:找出所有「半格」(理論值除以 6.25 是奇數倍,例如 6.25/18.75/…)的欄位,
## 兩兩配對,每一對裡隨機一個 -6.25(可能因此歸零)、另一個 +6.25,兩者就都補回
## 12.5 的整數倍網格,總和仍維持 100 不變。半格欄位的數量必定是偶數(12 個欄位總和
## 100 換算成 6.25 為單位一定是偶數,偶數總和裡奇數項的個數必為偶數),所以一定能
## 兩兩配對完,不會有落單的欄位。只在半格欄位之間搬動,完全不會動到本來就是整數倍
## (含 0)的欄位,不會重新引出父母雙方都沒有的國家。回傳是否真的有對齊到(有半格
## 欄位需要修正),給 inherit() 決定要不要扣掉一次變異額度。
static func _align_to_step_grid(percentages: Array[float]) -> bool:
	var half_step := Bloodline.STEP / 2.0
	var off_grid: Array[int] = []
	for i in range(percentages.size()):
		var half_step_count := roundi(percentages[i] / half_step)
		if half_step_count % 2 != 0:
			off_grid.append(i)

	off_grid.shuffle()
	var i := 0
	while i + 1 < off_grid.size():
		var loser := off_grid[i]
		var gainer := off_grid[i + 1]
		if randf() < 0.5:
			var swap := loser
			loser = gainer
			gainer = swap
		percentages[loser] -= half_step
		percentages[gainer] += half_step
		i += 2

	return not off_grid.is_empty()

## 就地修改 percentages:挑一個欄位 -amount、另一個不同欄位 +amount,
## 找不到合法候選(極端邊界情況)時直接放棄這次變異,理論值原封不動。
## 增加/減少的候選欄位都限定在「目前血統 > 0」的範圍內,
## 因此不會從 0% 的血統中憑空產生新的血統。
## 的血統池,不能無中生有變出父母雙方都完全沒有的國家(例如父母都是熊血,不該變異出獅血)。
static func _apply_mutation(percentages: Array[float], amount: float) -> void:
	var decrease_candidates: Array[int] = []
	var increase_candidates: Array[int] = []
	for i in range(percentages.size()):
		if percentages[i] > 0.0 and percentages[i] >= amount:
			decrease_candidates.append(i)
		if percentages[i] > 0.0 and percentages[i] <= Bloodline.TOTAL - amount:
			increase_candidates.append(i)

	if decrease_candidates.is_empty() or increase_candidates.is_empty():
		return

	var decrease_index: int = Util.get_random_from_array(decrease_candidates)
	var increase_pool := increase_candidates.filter(func(i): return i != decrease_index)
	if increase_pool.is_empty():
		return
	var increase_index: int = Util.get_random_from_array(increase_pool)

	percentages[decrease_index] -= amount
	percentages[increase_index] += amount
