class_name WarExhaustionRule
extends RefCounted

## WarExhaustion(0-100,每場 War 各自的 war_exhaustion_a/b)相關規則。

## 停戰後每月自然衰減量(不會瞬間歸零,見 spec),War 仍在進行中不衰減——只有已停戰的
## War 才會呼叫這個,見 war_world_time_events.gd 的 _decay_ended_war_exhaustion()。
const PEACETIME_MONTHLY_DECAY := 1.0

## 勝方小漲、敗方大漲,margin(戰果離 STALEMATE 幾級)越大增幅越大,索引 = 距離。
const GAIN_BY_MARGIN: Dictionary = {
	3: {"winner": 8.0, "loser": 14.0},
	2: {"winner": 5.0, "loser": 9.0},
	1: {"winner": 3.0, "loser": 5.0},
}
const STALEMATE_GAIN := 4.0


static func gain_for_grade(grade: int) -> Dictionary:
	var margin := absi(grade - GameEnums.BattleSettlementGrade.STALEMATE)
	if margin == 0:
		return {"winner_gain": STALEMATE_GAIN, "loser_gain": STALEMATE_GAIN, "stalemate_gain": STALEMATE_GAIN}
	var row: Dictionary = GAIN_BY_MARGIN[margin]
	return {"winner_gain": row["winner"], "loser_gain": row["loser"], "stalemate_gain": STALEMATE_GAIN}


static func decay(exhaustion: float) -> float:
	return clampf(exhaustion - PEACETIME_MONTHLY_DECAY, 0.0, 100.0)
