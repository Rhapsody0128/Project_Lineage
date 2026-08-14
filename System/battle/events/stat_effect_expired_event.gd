class_name StatEffectExpiredEvent
extends BattleEvent

var target: BattleHero
var target_name: String
var potential_types: Array[int]
var is_buff: bool

func _init(p_target: BattleHero, p_potential_types: Array[int], p_is_buff: bool) -> void:
	super._init(GameEnums.BattleEventType.STAT_EFFECT_EXPIRED)
	target = p_target
	target_name = p_target.name
	potential_types = p_potential_types
	is_buff = p_is_buff

func to_debug_string() -> String:
	return "%s 的%s效果解除(%s)" % [
		target_name,
		("增益" if is_buff else "減益"),
		GameEnums.format_potential_type_list(potential_types),
	]
