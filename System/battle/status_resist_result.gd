class_name StatusResistResult
extends RefCounted

## CombatResolver.judge_status_resist() 回傳值:恐懼/封印/攏絡這類控制型異常狀態
## 施加前的抵抗判定結果,見該函式註解。
var resisted: bool
var detail: String

func _init(p_resisted: bool, p_detail: String) -> void:
	resisted = p_resisted
	detail = p_detail
