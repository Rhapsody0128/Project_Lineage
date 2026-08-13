class_name SkillController
extends RefCounted

static var _skill_library: Array[Skill] = SkillLibrary.build()

static func get_skill_list() -> Array[Skill]:
	return _skill_library

static func get_skill(skill_index: int) -> Skill:
	return _skill_library[skill_index]

static func get_skill_list_by_rank(skill_rank: int) -> Array[Skill]:
	var result: Array[Skill] = []
	for skill in _skill_library:
		if skill.skill_rank == skill_rank:
			result.append(skill)
	return result

static func get_random_skill_list() -> Array[Skill]:
	if _skill_library.is_empty():
		return []
	var random_skill: Skill = _skill_library[Util.get_random_int(0, _skill_library.size())]
	return [random_skill]

static func get_random_skill_list_by_rank(skill_rank: int) -> Array[Skill]:
	var skill_list := get_skill_list_by_rank(skill_rank)
	if skill_list.is_empty():
		return []
	var random_skill: Skill = skill_list[Util.get_random_int(0, skill_list.size())]
	return [random_skill]

## 該武器能用的技能:bind_weapon 相符,或技能沒有綁定武器(EMPTY,徒手也能用)
static func get_skill_list_by_weapon(weapon_type: int) -> Array[Skill]:
	var result: Array[Skill] = []
	for skill in _skill_library:
		if skill.bind_weapon == weapon_type or skill.bind_weapon == GameEnums.WeaponType.EMPTY:
			result.append(skill)
	return result

static func get_random_skill_list_by_weapon(weapon_type: int) -> Array[Skill]:
	var skill_list := get_skill_list_by_weapon(weapon_type)
	if skill_list.is_empty():
		return []
	var random_skill: Skill = skill_list[Util.get_random_int(0, skill_list.size())]
	return [random_skill]
