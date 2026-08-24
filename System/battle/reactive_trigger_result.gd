class_name ReactiveTriggerResult
extends RefCounted

## CombatResolver.judge_reactive_trigger() 回傳值:反擊/完美迴避/反應治療/普通攻擊
## 追加一擊/普通攻擊範圍擴大這類武器被動機制共用的「是否發動」判定結果。
var triggered: bool
var detail: String

func _init(p_triggered: bool, p_detail: String) -> void:
	triggered = p_triggered
	detail = p_detail
