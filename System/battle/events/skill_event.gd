class_name SkillEvent
extends BattleEvent

var actor: BattleCharacter
var actor_name: String
var target: BattleCharacter
var target_name: String
var skill_name: String

func _init(p_actor: BattleCharacter, p_target: BattleCharacter, p_skill_name: String, p_detail: String = "") -> void:
	super._init(GameEnums.BattleEventType.SKILL, p_detail)
	actor = p_actor
	actor_name = p_actor.name
	target = p_target
	target_name = p_target.name
	skill_name = p_skill_name
