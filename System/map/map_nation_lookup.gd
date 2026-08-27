class_name MapNationLookup
extends RefCounted

## 從任一世界座標找出「離它最近的城鎮屬於哪個國家」,供旅行事件(System/event/map/travel/)
## 共用同一套判斷,不要各自複製一份迴圈——之後陸續加入的「國家好感度類」旅行事件都直接呼叫
## 這裡。找不到任何城鎮(理論上不會發生,MapObject.get_all() 固定至少 3 座城鎮)回傳 -1,
## 呼叫端比照 Party.nation_type 的既有慣例把 -1 當「沒有所屬國家」處理。
##
## 跟 RoamingEnemySpawner._nearest_town_nation() 是同一種查表邏輯,但那邊用實例快取的
## _map_objects 圖省一次 MapObject.get_all(),旅行事件觸發頻率低很多,直接即時查詢即可,
## 兩邊不共用同一份實作以免動到已經穩定運作的 spawner。
static func nearest_town_nation(pos: Vector2) -> int:
	var nearest_nation := -1
	var nearest_dist := INF
	for obj in MapObject.get_all():
		if obj.type != GameEnums.MapObjectType.TOWN:
			continue
		var dist := pos.distance_to(obj.position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_nation = obj.nation
	return nearest_nation
