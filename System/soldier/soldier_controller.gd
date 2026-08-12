class_name SoldierController
extends RefCounted

static func get_random_soldier() -> Soldier:
	var potential := PotentialController.get_random_potential()
	var skill_list := SkillController.get_random_skill_list()
	return Soldier.new("隨機的部隊", potential, skill_list, LevelSystem.new())
