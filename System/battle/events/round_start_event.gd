class_name RoundStartEvent
extends BattleEvent

## 回合邊界標記(1-indexed),battle.gd 重播時靠這一筆插入「第 N 回合」的分隔演出,
## round 以外不帶其他資料——這一回合實際發生了什麼全部是緊接在後面的其他事件。

var round: int

func _init(p_round: int) -> void:
	super._init(GameEnums.BattleEventType.ROUND_START)
	round = p_round
