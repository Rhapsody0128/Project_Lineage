class_name RoundStartEvent
extends BattleEvent

var round: int

func _init(p_round: int) -> void:
	super._init(GameEnums.BattleEventType.ROUND_START)
	round = p_round

func to_debug_string() -> String:
	return "------------第 %d 回合------------" % round
