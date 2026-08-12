class_name Soldier
extends RefCounted

var name: String
var soldiers_count_max: int
var death_soldiers_count: int
var wounded_soldiers_count: int
var potential: Potential
var skill_list: Array[Skill]
var level_system: LevelSystem

func _init(
	p_name: String,
	p_potential: Potential,
	p_skill_list: Array[Skill],
	p_level_system: LevelSystem
) -> void:
	name = p_name
	soldiers_count_max = 200
	death_soldiers_count = 0
	wounded_soldiers_count = 0
	potential = p_potential
	skill_list = p_skill_list
	level_system = p_level_system if p_level_system != null else LevelSystem.new()

var soldiers_count: int:
	get: return soldiers_count_max - death_soldiers_count - wounded_soldiers_count

var is_disabled: bool:
	get: return soldiers_count <= 0

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
