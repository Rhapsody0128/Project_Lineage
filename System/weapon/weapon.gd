class_name Weapon
extends RefCounted

var id: String
var name: String
var weapon_type: int
var potential: Potential
var equip_state: bool
var level_system: LevelSystem
var skill_list: Array[Skill]

func _init(
	p_name: String,
	p_potential: Potential,
	p_weapon_type: int,
	p_skill_list: Array[Skill],
	p_level_system: LevelSystem
) -> void:
	id = Util.generate_uuid()
	name = p_name
	potential = p_potential
	weapon_type = p_weapon_type
	equip_state = false
	skill_list = p_skill_list
	level_system = p_level_system

func change_equip_state(value: bool) -> void:
	equip_state = value

func _get_real_potential(initial_potential: float, ratio: float) -> float:
	return initial_potential + ratio * level_system.potential_level_constant

var strength: float:
	get: return _get_real_potential(potential.strength, potential.strength_ratio)
var agility: float:
	get: return _get_real_potential(potential.agility, potential.agility_ratio)
var perception: float:
	get: return _get_real_potential(potential.perception, potential.perception_ratio)
var vitality: float:
	get: return _get_real_potential(potential.vitality, potential.vitality_ratio)
var intelligence: float:
	get: return _get_real_potential(potential.intelligence, potential.intelligence_ratio)
var mentality: float:
	get: return _get_real_potential(potential.mentality, potential.mentality_ratio)

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
