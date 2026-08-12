class_name SkillController
extends RefCounted

static var _skill_library: Array[Skill] = _build_skill_library()

static func _build_skill_library() -> Array[Skill]:
	var library: Array[Skill] = []

	library.append(Skill.new(
		"火球術",
		"用法杖施放火球術",
		GameEnums.RankType.E,
		3,
		2,
		GameEnums.PotentialType.INTELLIGENCE,
		GameEnums.SkillType.ATTACK,
		GameEnums.WeaponType.STAFF,
		false,
		25.0,
		func(self_hero: BattleHero, enemy_hero: BattleHero, skill: Skill) -> void:
			var damage_base: float = self_hero.intelligence * 10.0
			var reduce_base: float = enemy_hero.mentality
			var damage: float = damage_base - (damage_base * (reduce_base / 200.0))
			self_hero.battle.log_event({
				"type": "skill", "actor": self_hero, "actor_name": self_hero.name,
				"target": enemy_hero, "target_name": enemy_hero.name, "skill_name": skill.name,
			})
			enemy_hero.be_attacked(damage)
	))

	library.append(Skill.new(
		"奮力一擊",
		"全力使用力量一擊",
		GameEnums.RankType.E,
		2,
		1,
		GameEnums.PotentialType.STRENGTH,
		GameEnums.SkillType.ATTACK,
		GameEnums.WeaponType.EMPTY,
		false,
		35.0,
		func(self_hero: BattleHero, enemy_hero: BattleHero, skill: Skill) -> void:
			var damage_base: float = self_hero.strength * 8.0
			var reduce_base: float = enemy_hero.vitality
			var damage: float = damage_base - (damage_base * (reduce_base / 200.0))
			self_hero.battle.log_event({
				"type": "skill", "actor": self_hero, "actor_name": self_hero.name,
				"target": enemy_hero, "target_name": enemy_hero.name, "skill_name": skill.name,
			})
			enemy_hero.be_attacked(damage)
	))

	return library

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
