class_name BattleResultGrader
extends RefCounted

## WarBattle 結算門檻判定,見 war_battle_simulation.gd 呼叫。


static func grade_for(progress: float) -> int:
	if progress >= 80.0:
		return GameEnums.BattleSettlementGrade.DECISIVE_VICTORY
	elif progress >= 50.0:
		return GameEnums.BattleSettlementGrade.VICTORY
	elif progress >= 20.0:
		return GameEnums.BattleSettlementGrade.NARROW_VICTORY
	elif progress > -20.0:
		return GameEnums.BattleSettlementGrade.STALEMATE
	elif progress > -50.0:
		return GameEnums.BattleSettlementGrade.NARROW_DEFEAT
	elif progress > -80.0:
		return GameEnums.BattleSettlementGrade.DEFEAT
	return GameEnums.BattleSettlementGrade.DECISIVE_DEFEAT


static func grade(battle: WarBattle) -> BattleResult:
	var grade_value := grade_for(battle.battle_progress)
	var gains := WarExhaustionRule.gain_for_grade(grade_value)
	var gain_a: float
	var gain_b: float
	if battle.battle_progress > 0.0:
		gain_a = gains["winner_gain"]
		gain_b = gains["loser_gain"]
	elif battle.battle_progress < 0.0:
		gain_a = gains["loser_gain"]
		gain_b = gains["winner_gain"]
	else:
		gain_a = gains["stalemate_gain"]
		gain_b = gains["stalemate_gain"]
	return BattleResult.new(
		battle.battle_id, battle.war_id, battle.nation_a, battle.nation_b,
		grade_value, battle.battle_progress, gain_a, gain_b
	)
