class_name Hero
extends RefCounted

var id: String
var name: String
var last_name: String
var age: int
var face_path: String
var traits: Array[CharacterTrait]
var potential: Potential
var skill_list: Array[Skill]
var level_system: LevelSystem

func _init(
	p_name: String,
	p_last_name: String,
	p_age: int,
	p_face_path: String,
	p_traits: Array[CharacterTrait],
	p_potential: Potential,
	p_skill_list: Array[Skill],
	p_level_system: LevelSystem
) -> void:
	id = Util.generate_uuid()
	name = p_name
	last_name = p_last_name
	age = p_age
	face_path = p_face_path
	traits = p_traits
	potential = p_potential
	skill_list = p_skill_list
	level_system = p_level_system

var full_name: String:
	get: return "%s·%s" % [name, last_name]

func gain_exp(exp_amount: int) -> void:
	level_system.gain_exp(exp_amount)

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
