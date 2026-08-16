class_name Potential
extends RefCounted

var strength: float
var vitality: float
var agility: float
var dexterity: float
var intelligence: float
var mentality: float
## 區間 0 - 200

var strength_ratio: float
var vitality_ratio: float
var agility_ratio: float
var dexterity_ratio: float
var intelligence_ratio: float
var mentality_ratio: float
## 區間 0.5 - 2

var strength_rank: int
var vitality_rank: int
var agility_rank: int
var dexterity_rank: int
var intelligence_rank: int
var mentality_rank: int

func _init(
	p_strength: float,
	p_vitality: float,
	p_agility: float,
	p_dexterity: float,
	p_intelligence: float,
	p_mentality: float,
	p_strength_ratio: float,
	p_vitality_ratio: float,
	p_agility_ratio: float,
	p_dexterity_ratio: float,
	p_intelligence_ratio: float,
	p_mentality_ratio: float
) -> void:
	strength = p_strength
	vitality = p_vitality
	agility = p_agility
	dexterity = p_dexterity
	intelligence = p_intelligence
	mentality = p_mentality
	strength_ratio = p_strength_ratio
	vitality_ratio = p_vitality_ratio
	agility_ratio = p_agility_ratio
	dexterity_ratio = p_dexterity_ratio
	intelligence_ratio = p_intelligence_ratio
	mentality_ratio = p_mentality_ratio
	strength_rank = rank_from_ratio(strength_ratio)
	vitality_rank = rank_from_ratio(vitality_ratio)
	agility_rank = rank_from_ratio(agility_ratio)
	dexterity_rank = rank_from_ratio(dexterity_ratio)
	intelligence_rank = rank_from_ratio(intelligence_ratio)
	mentality_rank = rank_from_ratio(mentality_ratio)

static func rank_from_ratio(ratio: float) -> int:
	var default_gap := 0.5
	var gap := 0.2
	if ratio <= default_gap:
		return GameEnums.RankType.E
	elif ratio <= default_gap + gap:
		return GameEnums.RankType.D
	elif ratio <= default_gap + gap * 2:
		return GameEnums.RankType.C
	elif ratio <= default_gap + gap * 3:
		return GameEnums.RankType.B
	elif ratio <= default_gap + gap * 4:
		return GameEnums.RankType.A
	elif ratio <= default_gap + gap * 5:
		return GameEnums.RankType.S
	elif ratio <= default_gap + gap * 6:
		return GameEnums.RankType.SS
	else:
		return GameEnums.RankType.SSS
