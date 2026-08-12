class_name Troop
extends RefCounted

var name: String
var parties: Array[Party]
var move_speed_constant: float = 0.01
var formation: Formation

func _init(p_name: String, p_parties: Array[Party], p_formation: Formation) -> void:
	name = p_name
	parties = p_parties
	formation = p_formation

var party_leader: Party:
	get: return parties[0]

var move_speed: float:
	get: return perception * move_speed_constant

func _get_real_potential(potential_type: int) -> float:
	var total_potential := 0.0
	for party in parties:
		total_potential += party.get_potential(potential_type)
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
