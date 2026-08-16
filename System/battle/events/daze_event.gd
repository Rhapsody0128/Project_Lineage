class_name DazeEvent
extends BattleEvent

var actor: BattleCharacter
var actor_name: String

func _init(p_actor: BattleCharacter, p_detail: String = "") -> void:
	super._init(GameEnums.BattleEventType.DAZE, p_detail)
	actor = p_actor
	actor_name = p_actor.name
