class_name StatEffectEvent
extends BattleEvent

var target: BattleHero
var target_name: String
var potential_types: Array[int]
var multiplier: float
var rounds: int
var is_buff: bool

func _init(
	p_target: BattleHero, p_potential_types: Array[int], p_multiplier: float, p_rounds: int
) -> void:
	super._init(GameEnums.BattleEventType.STAT_EFFECT)
	target = p_target
	target_name = p_target.name
	potential_types = p_potential_types
	multiplier = p_multiplier
	rounds = p_rounds
	is_buff = p_multiplier > 0.0
