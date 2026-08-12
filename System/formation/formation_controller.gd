class_name FormationController
extends RefCounted

# 7 6 5 4 3 2 1 0
#               1
#               2
#               3
# ----------------
# 3
# 2     我方
# 1
# 0 1 2 3 4 5 6 7
static var _formation_list: Array[Formation] = _build_formation_list()

static func _build_formation_list() -> Array[Formation]:
	var cells: Array[FormationCell] = [
		FormationCell.new(Vector2i(1, 1), GameEnums.SkillType.ATTACK),
		FormationCell.new(Vector2i(1, 2), GameEnums.SkillType.DEFEND),
		FormationCell.new(Vector2i(2, 1), GameEnums.SkillType.BUFF),
		FormationCell.new(Vector2i(2, 2), GameEnums.SkillType.DEBUFF),
		FormationCell.new(Vector2i(3, 1), GameEnums.SkillType.HEAL),
		FormationCell.new(Vector2i(3, 2), GameEnums.SkillType.ATTACK),
	]
	return [Formation.new("方陣", cells)]

static func get_formation_list() -> Array[Formation]:
	return _formation_list

static func get_formation(formation_index: int) -> Formation:
	return _formation_list[formation_index]

static func get_random_formation() -> Formation:
	var formation_index := Util.get_random_int(0, _formation_list.size())
	return get_formation(formation_index)
