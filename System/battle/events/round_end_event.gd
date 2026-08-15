class_name RoundEndEvent
extends BattleEvent

var round: int

func _init(p_round: int) -> void:
	super._init(GameEnums.BattleEventType.ROUND_END)
	round = p_round
