class_name DamageEvent
extends BattleEvent

var target: BattleHero
var target_name: String
var damage_points: int
var remaining_hp: int
var is_critical: bool

func _init(
	p_target: BattleHero, p_damage_points: int, p_remaining_hp: int,
	p_is_critical: bool = false, p_detail: String = ""
) -> void:
	super._init(GameEnums.BattleEventType.DAMAGE, p_detail)
	target = p_target
	target_name = p_target.name
	damage_points = p_damage_points
	remaining_hp = p_remaining_hp
	is_critical = p_is_critical

func to_debug_string() -> String:
	var crit_text := "(暴擊！)" if is_critical else ""
	return "%s 受到 %d 點傷害%s(剩餘 HP %d)" % [target_name, damage_points, crit_text, remaining_hp]
