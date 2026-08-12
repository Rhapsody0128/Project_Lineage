class_name FormationCell
extends RefCounted

var position: Vector2i
var position_skill_type: int
var weapon: Weapon

func _init(p_position: Vector2i, p_position_skill_type: int) -> void:
	position = p_position
	position_skill_type = p_position_skill_type
	weapon = WeaponController.get_default_weapon()

func set_weapon(p_weapon: Weapon) -> void:
	weapon = p_weapon
