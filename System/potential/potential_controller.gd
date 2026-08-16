class_name PotentialController
extends RefCounted

## 六大素質隨機基礎值:範圍 0~200(見 CombatResolver.judge_dodge()/SkillEffectLibrary
static func get_random_potential() -> Potential:
	return Potential.new(
		Util.get_random_int(0, 25),
		Util.get_random_int(0, 25),
		Util.get_random_int(0, 25),
		Util.get_random_int(0, 25),
		Util.get_random_int(0, 25),
		Util.get_random_int(0, 25),
		Util.get_random_float(0.5, 1),
		Util.get_random_float(0.5, 1),
		Util.get_random_float(0.5, 1),
		Util.get_random_float(0.5, 1),
		Util.get_random_float(0.5, 1),
		Util.get_random_float(0.5, 1)
	)
