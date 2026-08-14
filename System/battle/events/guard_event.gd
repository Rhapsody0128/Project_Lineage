class_name GuardEvent
extends BattleEvent

var actor: BattleHero
var actor_name: String
var target: BattleHero
var target_name: String
var attacker: BattleHero
var attacker_name: String
var skill_name: String

func _init(
	p_actor: BattleHero, p_target: BattleHero, p_attacker: BattleHero,
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

func to_debug_string() -> String:
	return "%s 飛身守護,替 %s 承受這次攻擊" % [actor_name, target_name]
