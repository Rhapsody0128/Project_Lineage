class_name WarBattlePositionPicker
extends RefCounted

## 戰場生成座標的唯一入口——目前版本回傳兩國城鎮座標的中點附近隨機一點,包成獨立函式方便
## 日後換成真正的邊境/路徑感知版本而不用動呼叫端(war_battle_spawner.gd)。MapObject.
## get_all() 每個 BloodlineNation 剛好對應唯一一座 TOWN,這裡直接查表(國家→座標),
## 跟 System/map/map_terrain_mask.gd 的 MapTerrainMask.nation_at()(座標→國家)方向相反。
##
## 中點附近加隨機偏移(不是直接回傳中點)——同一場 War 同時有多個 WarBattle 時,
## 兩國城鎮位置固定,若每次都回傳同一個中點,WarBattleSpawner.MAX_CONCURRENT_BATTLES
## 個 ⚔ 圖示會整疊堆在同一個座標上互相遮蓋,不方便玩家個別點擊。

## 偏移半徑——比 WarBattleVisual.RADIUS 大得多,確保同一場戰爭疊在一起的多個戰場圖示
## 彼此不重疊。
const POSITION_JITTER_RADIUS := 150.0

static func pick_position(nation_a: int, nation_b: int) -> Vector2:
	var midpoint := (_town_position(nation_a) + _town_position(nation_b)) / 2.0
	var angle := Util.get_random_float(0.0, TAU)
	var distance := Util.get_random_float(0.0, POSITION_JITTER_RADIUS)
	var offset := Vector2.RIGHT.rotated(angle) * distance
	return Vector2(
		clampf(midpoint.x + offset.x, 0.0, MapSystem.MAP_SIZE.x),
		clampf(midpoint.y + offset.y, 0.0, MapSystem.MAP_SIZE.y)
	)


static func _town_position(nation_id: int) -> Vector2:
	for obj in MapObject.get_all():
		if obj.type == GameEnums.MapObjectType.TOWN and obj.nation == nation_id:
			return obj.position
	return MapSystem.MAP_SIZE / 2.0
