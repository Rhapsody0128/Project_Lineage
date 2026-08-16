class_name BaseProduction
extends RefCounted

## 根據地生產類建築的每日產出公式:基礎產量 + 派遣角色對應素質值的加成,素質越高
## 派遣過去產出越好,不用另外開等級/科技系統就能反映角色差異。

static func compute_daily_yield(building: Building, character: Character) -> int:
	if character == null:
		return 0
	var attribute_value := character.get_potential(building.potential_type)
	return building.base_yield + int(attribute_value / 20.0)
