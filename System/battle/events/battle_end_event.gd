class_name BattleEndEvent
extends BattleEvent

var round: int
var self_total: int
var enemy_total: int
var result: GameEnums.BattleResultType

func _init(p_round: int, p_self_total: int, p_enemy_total: int, p_result: GameEnums.BattleResultType) -> void:
	super._init(GameEnums.BattleEventType.BATTLE_END)
	round = p_round
	self_total = p_self_total
	enemy_total = p_enemy_total
	result = p_result
