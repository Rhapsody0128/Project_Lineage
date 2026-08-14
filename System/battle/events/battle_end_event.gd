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

func to_debug_string() -> String:
	var result_text: String
	match result:
		GameEnums.BattleResultType.SELF_WIN:
			result_text = "我方勝利"
		GameEnums.BattleResultType.ENEMY_WIN:
			result_text = "敵方勝利"
		_:
			result_text = "平手"
	return "戰鬥結束(共 %d 回合)，%s(我方剩餘 HP %d，敵方剩餘 HP %d)" % [round, result_text, self_total, enemy_total]
