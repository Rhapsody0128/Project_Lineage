class_name DodgeEvent
extends BattleEvent

var actor: BattleHero
var actor_name: String
var target: BattleHero
var target_name: String

func _init(p_actor: BattleHero, p_target: BattleHero, p_detail: String = "") -> void:
	super._init(GameEnums.BattleEventType.DODGE, p_detail)
	actor = p_actor
	actor_name = p_actor.name
	target = p_target
	target_name = p_target.name
