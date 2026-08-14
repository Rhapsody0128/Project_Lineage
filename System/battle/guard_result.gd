class_name GuardResult
extends RefCounted

## CombatResolver.resolve_guard() 回傳值,取代舊版
## {"target": BattleHero, "detail": String, "damage_multiplier": float} Dictionary。
var target: BattleHero
var detail: String
var damage_multiplier: float

func _init(p_target: BattleHero, p_detail: String, p_damage_multiplier: float) -> void:
	target = p_target
	detail = p_detail
	damage_multiplier = p_damage_multiplier
