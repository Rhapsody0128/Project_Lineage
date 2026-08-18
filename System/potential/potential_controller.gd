class_name PotentialController
extends RefCounted

## 六大素質隨機基礎值:範圍 0~200(見 CombatResolver.judge_dodge()/SkillEffectLibrary
## rank_type 不填(-1)= 六項素質的成長評級各自獨立隨機(維持原本行為);指定時,六項
## 素質各自仍在對應 rank 的 ratio 區間內取隨機值,但換算出來的 Potential Rank 保證
## 等於 rank_type,見 _random_ratio()。
static func get_random_potential(rank_type: int = -1) -> Potential:
	return Potential.new(
		Util.get_random_int(0, 25),
		Util.get_random_int(0, 25),
		Util.get_random_int(0, 25),
		Util.get_random_int(0, 25),
		Util.get_random_int(0, 25),
		Util.get_random_int(0, 25),
		_random_ratio(rank_type),
		_random_ratio(rank_type),
		_random_ratio(rank_type),
		_random_ratio(rank_type),
		_random_ratio(rank_type),
		_random_ratio(rank_type)
	)

## rank_type 不填(-1)沿用原本 0.5~1.0 全區間隨機;指定時只在該 rank 對應的 ratio
## 區間內取隨機值,Potential.rank_from_ratio() 換算出的結果必定等於 rank_type。
static func _random_ratio(rank_type: int) -> float:
	if rank_type == -1:
		return Util.get_random_float(0.5, 1.0)
	var lower := Potential.BASE_RATIO + Potential.RANK_GAP * rank_type
	return Util.get_random_float(lower, lower + Potential.RANK_GAP)
