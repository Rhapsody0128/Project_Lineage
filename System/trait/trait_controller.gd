class_name TraitController
extends RefCounted

# 個性/特質池,取自「遊戲企劃設定總整理.md」五、角色個性系統的範例。
# 個性與技能完全分開,是角色天生特徵;目前僅有資料模型與描述文字,
# 機制效果(命中率/戰鬥AI 傾向等)尚未實作,見 CLAUDE.md 已知待辦。
static func _pool() -> Array[CharacterTrait]:
	var pool: Array[CharacterTrait] = []
	pool.append(CharacterTrait.new("目盲", "命中率降低", GameEnums.TraitPolarity.NEGATIVE))
	pool.append(CharacterTrait.new("勇猛", "提高攻擊相關能力", GameEnums.TraitPolarity.POSITIVE))
	pool.append(CharacterTrait.new("膽小", "低血量時更容易退縮", GameEnums.TraitPolarity.NEGATIVE))
	return pool

## 從個性池中隨機抽 count 個不重複的個性
static func get_random_traits(count: int) -> Array[CharacterTrait]:
	var pool := _pool()
	pool.shuffle()
	var result: Array[CharacterTrait] = []
	for i in range(min(count, pool.size())):
		result.append(pool[i])
	return result
