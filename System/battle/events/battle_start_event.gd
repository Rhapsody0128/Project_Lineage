class_name BattleStartEvent
extends BattleEvent

func _init() -> void:
	super._init(GameEnums.BattleEventType.BATTLE_START)

func to_debug_string() -> String:
	return "戰鬥開始"
