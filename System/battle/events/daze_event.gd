class_name DazeEvent
extends BattleEvent

## actor 這一輪骰到「發呆」(BattleAi 的保底最低權重選項,見 battle_ai.gd 檔頭註解),
## 這一次行動什麼都不做,detail 帶骰選成因文字。

var actor: BattleCharacter
var actor_name: String

func _init(p_actor: BattleCharacter, p_detail: String = "") -> void:
	super._init(GameEnums.BattleEventType.DAZE, p_detail)
	actor = p_actor
	actor_name = p_actor.name
