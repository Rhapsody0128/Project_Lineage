class_name Util
extends RefCounted

## 取得隨機整數,範圍為 [min_value, max_value)
static func get_random_int(min_value: int, max_value: int) -> int:
	if max_value <= min_value:
		return min_value
	return randi_range(min_value, max_value - 1)

## 取得隨機浮點數,範圍為 [min_value, max_value],四捨五入至小數點後2位
static func get_random_float(min_value: float, max_value: float) -> float:
	var value := randf_range(min_value, max_value)
	return roundf(value * 100.0) / 100.0

static func get_random_from_array(array: Array):
	if array.is_empty():
		return null
	return array[get_random_int(0, array.size())]

## 從 enum 型別(以裸露方式傳入,例如 GameEnums.WeaponType)隨機取得一個值
static func get_random_enum_value(enum_dict: Dictionary) -> int:
	var values := enum_dict.values()
	return values[get_random_int(0, values.size())]

static func generate_uuid() -> String:
	var bytes := PackedByteArray()
	for i in range(16):
		bytes.append(randi_range(0, 255))
	bytes[6] = (bytes[6] & 0x0F) | 0x40
	bytes[8] = (bytes[8] & 0x3F) | 0x80
	var hex := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [
		hex.substr(0, 8),
		hex.substr(8, 4),
		hex.substr(12, 4),
		hex.substr(16, 4),
		hex.substr(20, 12),
	]

static func clone(value):
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	return value

## 依照 Dictionary[String, float] 的權重表,隨機取得一個 key
static func get_random_chance_item(chance_map: Dictionary) -> String:
	return get_random_chance_item_detailed(chance_map).key

## 跟 get_random_chance_item() 同一套邏輯,但額外回傳這次骰到的值與權重總和
## ({"key": String, "roll": float, "total": float}),給戰報 UI 組出「骰到多少 / 總權重
## 多少 → 選到哪個」的完整說明用,避免呼叫端各自重算一次權重總和。
static func get_random_chance_item_detailed(chance_map: Dictionary) -> Dictionary:
	var total_chance := 0.0
	for value in chance_map.values():
		total_chance += value
	var roll := get_random_float(0.0, total_chance)
	var remaining := roll
	for key in chance_map.keys():
		remaining -= chance_map[key]
		if remaining <= 0:
			return {"key": key, "roll": roll, "total": total_chance}
	return {"key": chance_map.keys()[-1], "roll": roll, "total": total_chance}
