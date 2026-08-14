class_name DodgeResult
extends RefCounted

## CombatResolver.judge_dodge() 回傳值,取代舊版 {"dodged": bool, "detail": String} Dictionary。
var dodged: bool
var detail: String

func _init(p_dodged: bool, p_detail: String) -> void:
	dodged = p_dodged
	detail = p_detail
