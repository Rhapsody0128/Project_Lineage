class_name RoundEndEvent
extends BattleEvent

## 回合邊界標記,跟 RoundStartEvent 成對出現(見該檔案),round 是剛結束的那個回合數。

var round: int

func _init(p_round: int) -> void:
	super._init(GameEnums.BattleEventType.ROUND_END)
	round = p_round
