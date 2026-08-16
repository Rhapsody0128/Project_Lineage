class_name MoveEvent
extends BattleEvent

var actor: BattleCharacter
var actor_name: String
var target: BattleCharacter
var target_name: String
var from: Vector2i
var path: Array[Vector2i]
var to: Vector2i
var away: bool

func _init(
	p_actor: BattleCharacter, p_target: BattleCharacter,
	p_from: Vector2i, p_path: Array[Vector2i], p_to: Vector2i, p_away: bool,
	p_detail: String = ""
) -> void:
	super._init(GameEnums.BattleEventType.MOVE, p_detail)
	actor = p_actor
	actor_name = p_actor.name
	target = p_target
	target_name = p_target.name
	from = p_from
	path = p_path
	to = p_to
	away = p_away
