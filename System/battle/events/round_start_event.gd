class_name RoundStartEvent
extends BattleEvent

var round: int

func _init(p_round: int) -> void:
	super._init(GameEnums.BattleEventType.ROUND_START)
	round = p_round
