class_name LevelSystem
extends RefCounted

var level: int = 1
var exp: int = 0
var need_exp_to_upgrade: Array[int] = [0, 10, 30, 50]
var potential_level_ratio: float = 5.0

func _init(p_level: int = 1) -> void:
	level = p_level
	exp = 0

func gain_exp(exp_amount: int) -> void:
	if level >= need_exp_to_upgrade.size():
		return
	exp += exp_amount
	_judge_can_upgrade()

func _judge_can_upgrade() -> void:
	if level >= need_exp_to_upgrade.size():
		return
	var need_exp: int = need_exp_to_upgrade[level]
	if need_exp < exp:
		exp -= need_exp
		level += 1
		_judge_can_upgrade()

var potential_level_constant: float:
	get: return level * potential_level_ratio
