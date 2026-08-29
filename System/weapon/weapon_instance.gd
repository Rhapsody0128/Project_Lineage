class_name WeaponInstance
extends RefCounted

## 一把已抽好素質的武器:武器類型 + rank + 抽到的素質點數(GameEnums.PotentialType -> int)。
## 純資料容器,不是可拾取實體——見 WeaponStore(玩家全域裝備欄)/WeaponLibrary(抽點邏輯)。
var weapon_type: GameEnums.WeaponType
var rank_type: GameEnums.RankType
var stat_points: Dictionary = {}

func _init(p_weapon_type: int, p_rank_type: int, p_stat_points: Dictionary = {}) -> void:
	weapon_type = p_weapon_type
	rank_type = p_rank_type
	stat_points = p_stat_points

func get_point(potential_type: int) -> int:
	return stat_points.get(potential_type, 0)

func total_points() -> int:
	var total := 0
	for value in stat_points.values():
		total += value
	return total
