class_name AttackEvent
extends BattleEvent

var actor: BattleCharacter
var actor_name: String
var target: BattleCharacter
var target_name: String

func _init(p_actor: BattleCharacter, p_target: BattleCharacter, p_detail: String = "") -> void:
	super._init(GameEnums.BattleEventType.ATTACK, p_detail)
	actor = p_actor
	actor_name = p_actor.name
	target = p_target
	target_name = p_target.name
