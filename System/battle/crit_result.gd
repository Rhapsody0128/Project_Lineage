class_name CritResult
extends RefCounted

## CombatResolver.judge_crit() 回傳值,取代舊版 {"critical": bool, "detail": String} Dictionary。
var critical: bool
var detail: String

func _init(p_critical: bool, p_detail: String) -> void:
	critical = p_critical
	detail = p_detail
