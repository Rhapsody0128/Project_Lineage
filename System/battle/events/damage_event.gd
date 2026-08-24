class_name DamageEvent
extends BattleEvent

var target: BattleCharacter
var target_name: String
var damage_points: int
var remaining_hp: int
var is_critical: bool
## 護盾吸收後剩餘的護盾值(見 CombatResolver.apply_damage()),給 BattlePartyRoster
## 的護盾條同步用——傷害可能消耗掉部分/全部護盾,單靠 ShieldEvent(只在護盾施放當下
## 記一次)沒辦法反映後續每次受傷的消耗進度。
var remaining_shield: int

func _init(
	p_target: BattleCharacter, p_damage_points: int, p_remaining_hp: int,
	p_is_critical: bool = false, p_detail: String = "", p_remaining_shield: int = 0
) -> void:
	super._init(GameEnums.BattleEventType.DAMAGE, p_detail)
	target = p_target
	target_name = p_target.name
	damage_points = p_damage_points
	remaining_hp = p_remaining_hp
	is_critical = p_is_critical
	remaining_shield = p_remaining_shield
