class_name WeaponController
extends RefCounted

static func get_default_weapon() -> Weapon:
	var potential := Potential.new(10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
	return Weapon.new("預設劍", potential, GameEnums.WeaponType.SWORD, [], LevelSystem.new())

static func get_random_weapon() -> Weapon:
	return get_random_weapon_of_type(_get_random_weapon_type())

static func get_random_weapon_of_type(weapon_type: int) -> Weapon:
	var potential := PotentialController.get_random_potential()
	var weapon_name := _get_random_name(weapon_type)
	var skill_list := SkillController.get_random_skill_list_by_weapon(weapon_type)
	return Weapon.new(weapon_name, potential, weapon_type, skill_list, LevelSystem.new())

static func _get_random_name(weapon_type: int) -> String:
	var key: String = GameEnums.WeaponType.keys()[weapon_type]
	return key.capitalize()

static func _get_random_weapon_type() -> int:
	return Util.get_random_enum_value(GameEnums.WeaponType)
