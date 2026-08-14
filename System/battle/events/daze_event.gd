class_name DazeEvent
extends BattleEvent

var actor: BattleHero
var actor_name: String

func _init(p_actor: BattleHero, p_detail: String = "") -> void:
	super._init(GameEnums.BattleEventType.DAZE, p_detail)
	actor = p_actor
	actor_name = p_actor.name

func to_debug_string() -> String:
	return "%s 猶豫不決" % actor_name
