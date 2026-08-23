class_name SkillCountDrawTable
extends RefCounted

## 「血統評級(Character.noble_bloodline_rank,GameEnums.RankType)→ 初始技能數」機率表:
## 列對應 RankType(F~SSS),欄依序是技能數 1/2/3/4(對齊 SkillController.
## MAX_SKILLS_PER_CHARACTER=4 上限),列數/欄數需跟著兩者一起維護。血統評級越高,
## 抽到較多技能數的機率越高(F 幾乎必定只有 1 個,SSS 大機率 3~4 個)。列總和 100。
const TABLE: Array[Array] = [
    [90.0, 10.0,  0.0,  0.0], # F
    [72.0, 22.0,  6.0,  0.0], # E
    [55.0, 30.0, 13.0,  2.0], # D
    [40.0, 32.0, 22.0,  6.0], # C
    [28.0, 32.0, 28.0, 12.0], # B
    [20.0, 30.0, 32.0, 18.0], # A
    [14.0, 25.0, 35.0, 26.0], # S
    [10.0, 20.0, 36.0, 34.0], # SS
    [ 5.0, 15.0, 30.0, 50.0], # SSS
]

## 依 bloodline_rank(Character.noble_bloodline_rank)那一列權重骰出初始技能數(1~4)。
## 呼叫端把結果傳給 SkillController.get_skill_list_by_weapon() 的 target_count。
static func roll(bloodline_rank: int) -> int:
	var weights := TABLE[bloodline_rank]
	var total := 0.0
	for weight in weights:
		total += weight
	var picked := Util.get_random_float(0.0, total)
	var remaining := picked
	for i in range(weights.size()):
		remaining -= weights[i]
		if remaining <= 0:
			return i + 1
	return weights.size()
