class_name HealEvent
extends BattleEvent

## 單純的 HP 回復(治療技能/HEAL 類效果),跟 ShieldEvent(獨立於 HP 之外的緩衝值)分開
## 記錄——remaining_hp 是回復後已經 clamp 過上限的最終值,不需要呼叫端自己再夾一次。

var target: BattleCharacter
var target_name: String
var heal_points: int
var remaining_hp: int

func _init(p_target: BattleCharacter, p_heal_points: int, p_remaining_hp: int, p_detail: String = "") -> void:
	super._init(GameEnums.BattleEventType.HEAL, p_detail)
	target = p_target
	target_name = p_target.name
	heal_points = p_heal_points
	remaining_hp = p_remaining_hp
