class_name HealEvent
extends BattleEvent

var target: BattleCharacter
var target_name: String
var heal_points: int
var remaining_hp: int

func _init(p_target: BattleCharacter, p_heal_points: int, p_remaining_hp: int, p_detail: String = "") -> void:
	super._init(GameEnums.BattleEventType.HEAL, p_detail)
	target = p_target
	target_name = p_target.name
	heal_points = p_heal_points
	remaining_hp = p_remaining_hp
