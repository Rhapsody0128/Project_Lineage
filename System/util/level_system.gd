class_name LevelSystem
extends RefCounted

var level: int = 1
var exp: int = 0
var level_required_exp: Array[int] = [
    0,      # Lv1
    10,     # Lv2
    30,     # Lv3
    50,     # Lv4
    80,     # Lv5
    120,    # Lv6
    170,    # Lv7
    230,    # Lv8
    300,    # Lv9
    380,    # Lv10
    470,    # Lv11
    570,    # Lv12
    680,    # Lv13
    800,    # Lv14
    930,    # Lv15
    1070,   # Lv16
    1220,   # Lv17
    1380,   # Lv18
    1550,   # Lv19
    1730    # Lv20
]
var potential_level_ratio: float = 5.0

func _init(p_level: int = 1) -> void:
	level = p_level
	exp = 0

func gain_exp(exp_amount: int) -> void:
	if level >= level_required_exp.size():
		return
	exp += exp_amount
	_judge_can_upgrade()

func _judge_can_upgrade() -> void:
	if level >= level_required_exp.size():
		return
	var need_exp: int = level_required_exp[level]
	if need_exp < exp:
		exp -= need_exp
		level += 1
		_judge_can_upgrade()

var potential_level_constant: float:
	get: return level * potential_level_ratio

## 升到下一級所需的總 exp(UI 計量表用,例如角色面板的 EXP/NextExp 條)。
## 已經到 level_required_exp 定義的最高等級時回傳 0,呼叫端用 is_max_level() 判斷要不要顯示滿條。
func exp_to_next_level() -> int:
	if is_max_level():
		return 0
	return level_required_exp[level]

func is_max_level() -> bool:
	return level >= level_required_exp.size()
