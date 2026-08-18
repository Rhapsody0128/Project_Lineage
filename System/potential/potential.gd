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

## 根據比例計算血統排名
##
## 排名規則：
## F   : ratio <= 0.5
## E   : 0.5 < ratio <= 0.7
## D   : 0.7 < ratio <= 0.9
## C   : 0.9 < ratio <= 1.1
## B   : 1.1 < ratio <= 1.3
## A   : 1.3 < ratio <= 1.5
## S   : 1.5 < ratio <= 1.7
## SS  : 1.7 < ratio <= 1.9
## SSS : ratio > 1.9
##
## 基準值為 0.5，每增加 0.2 提升一個排名。
## 最低為 F，最高限制為 SSS。
static func rank_from_ratio(ratio: float) -> int:
	const BASE_RATIO := 0.5
	const RANK_GAP := 0.2

	var rank := floori((ratio - BASE_RATIO) / RANK_GAP) + GameEnums.RankType.F

	return clampi(
		rank,
		GameEnums.RankType.F,
		GameEnums.RankType.SSS
	)
