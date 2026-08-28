class_name BattleResult
extends RefCounted

## WarBattle 結算的輸出——見 battle_result_grader.gd 的 grade()。grade 一律從 nation_a
## 視角判定,玩家支援的若是 nation_b,呼叫端要用 mirror_grade() 換算成玩家視角戰果,
## 不要自己反查表。

var battle_id: String
var war_id: String
var nation_a: int
var nation_b: int
var grade: int   # GameEnums.BattleSettlementGrade,nation_a 視角
var final_progress: float
var exhaustion_gain_a: float
var exhaustion_gain_b: float


func _init(p_battle_id: String, p_war_id: String, p_nation_a: int, p_nation_b: int,
		p_grade: int, p_final_progress: float, p_exhaustion_gain_a: float,
		p_exhaustion_gain_b: float) -> void:
	battle_id = p_battle_id
	war_id = p_war_id
	nation_a = p_nation_a
	nation_b = p_nation_b
	grade = p_grade
	final_progress = p_final_progress
	exhaustion_gain_a = p_exhaustion_gain_a
	exhaustion_gain_b = p_exhaustion_gain_b


## BattleSettlementGrade 是對稱宣告(DECISIVE_VICTORY(0)↔DECISIVE_DEFEAT(6)、
## VICTORY(1)↔DEFEAT(5)、NARROW_VICTORY(2)↔NARROW_DEFEAT(4)、STALEMATE(3)↔自己),
## 鏡像換算直接用總數相減即可,不需要另開一張對照表。
static func mirror_grade(grade: int) -> int:
	return GameEnums.BattleSettlementGrade.DECISIVE_DEFEAT - grade
