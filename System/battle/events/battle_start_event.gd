class_name BattleStartEvent
extends BattleEvent

## 開場標記,不帶任何欄位——battle.gd 重播時靠這一筆決定「整場戰報從這裡開始播」,
## 之後緊接著的是雙方初始站位(見 Battle.start() 開頭記錄順序)。

func _init() -> void:
	super._init(GameEnums.BattleEventType.BATTLE_START)
