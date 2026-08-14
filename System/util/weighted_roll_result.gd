class_name WeightedRollResult
extends RefCounted

## Util.get_random_chance_item_detailed() 回傳值,取代舊版
## {"key": String, "roll": float, "total": float} Dictionary。
var key: String
var roll: float
var total: float

func _init(p_key: String, p_roll: float, p_total: float) -> void:
	key = p_key
	roll = p_roll
	total = p_total
