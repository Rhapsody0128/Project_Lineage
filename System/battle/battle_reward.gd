class_name BattleReward
extends RefCounted

## RankType(F..SSS)分別對應的戰鬥勝利 EXP,先用等差遞增的預留位置數值,之後依遊戲數值
## 調整這張表即可,不用動呼叫端。
const RANK_EXP: Array[int] = [50, 100, 150, 200, 250, 300, 350, 400, 450]

static func exp_for_rank(rank_type: int) -> int:
	return RANK_EXP[clampi(rank_type, 0, RANK_EXP.size() - 1)]

## 戰鬥勝利(SELF_WIN)後,依敵方 Party 的 rank_type 查表,把「完整」EXP(不是平分)發給
## 我方在場的每一個角色。戰敗/平手不呼叫這裡。
static func grant_victory_exp(battle: Battle) -> void:
	if battle.result != GameEnums.BattleResultType.SELF_WIN:
		return
	var exp_amount := exp_for_rank(battle.enemy_rank_type)
	for battle_character in battle.self_characteres:
		battle_character.character.gain_exp(exp_amount)
