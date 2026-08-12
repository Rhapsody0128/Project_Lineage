class_name Party
extends RefCounted

var name: String
var hero: Hero
var soldiers: Array[Soldier]
var skill_list: Array[Skill]
var formation_cell: FormationCell

func _init(p_name: String, p_hero: Hero, p_soldiers: Array[Soldier]) -> void:
	name = p_name
	hero = p_hero
	soldiers = p_soldiers
	skill_list = hero.skill_list

func set_formation_cell(p_formation_cell: FormationCell) -> void:
	formation_cell = p_formation_cell

## 陣形中陣形役(攻擊位、防禦位等等),未編入陣形時為 null
var position_skill_type:
	get:
		if formation_cell != null:
			return formation_cell.position_skill_type
		return null

## 陣形中取得的武器,未編入陣形時為 null
var weapon: Weapon:
	get:
		if formation_cell != null:
			return formation_cell.weapon
		return null

var total_soldier_count: int:
	get:
		var total := 0
		for soldier in soldiers:
			total += soldier.soldiers_count
		return total

var total_wounded_soldier_count: int:
	get:
		var total := 0
		for soldier in soldiers:
			total += soldier.wounded_soldiers_count
		return total

var total_soldier_is_disabled: bool:
	get:
		for soldier in soldiers:
			if not soldier.is_disabled:
				return false
		return true

func _get_real_potential(potential_type: int) -> float:
	var total_potential: float = hero.get_potential(potential_type) * 0.4
	if weapon != null:
		total_potential += weapon.get_potential(potential_type) * 0.3
	for soldier in soldiers:
		if not soldier.is_disabled:
			total_potential += soldier.get_potential(potential_type) * 0.06
	return total_potential

var strength: float:
	get: return _get_real_potential(GameEnums.PotentialType.STRENGTH)
var agility: float:
	get: return _get_real_potential(GameEnums.PotentialType.AGILITY)
var perception: float:
	get: return _get_real_potential(GameEnums.PotentialType.PERCEPTION)
var vitality: float:
	get: return _get_real_potential(GameEnums.PotentialType.VITALITY)
var intelligence: float:
	get: return _get_real_potential(GameEnums.PotentialType.INTELLIGENCE)
var mentality: float:
	get: return _get_real_potential(GameEnums.PotentialType.MENTALITY)

func get_potential(potential_type: int) -> float:
	match potential_type:
		GameEnums.PotentialType.STRENGTH:
			return strength
		GameEnums.PotentialType.AGILITY:
			return agility
		GameEnums.PotentialType.PERCEPTION:
			return perception
		GameEnums.PotentialType.VITALITY:
			return vitality
		GameEnums.PotentialType.INTELLIGENCE:
			return intelligence
		GameEnums.PotentialType.MENTALITY:
			return mentality
		_:
			return 0.0
