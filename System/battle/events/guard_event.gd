class_name GuardEvent
extends BattleEvent

var actor: BattleCharacter
var actor_name: String
var target: BattleCharacter
var target_name: String
var attacker: BattleCharacter
var attacker_name: String
var skill_name: String

func _init(
	p_actor: BattleCharacter, p_target: BattleCharacter, p_attacker: BattleCharacter,
	p_skill_name: String, p_detail: String = ""
) -> void:
	super._init(GameEnums.BattleEventType.GUARD, p_detail)
	actor = p_actor
	actor_name = p_actor.name
	target = p_target
	target_name = p_target.name
	attacker = p_attacker
	attacker_name = p_attacker.name
	skill_name = p_skill_name
