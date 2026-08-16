class_name BaseSystem
extends RefCounted

## 根據地畫面的點擊命中測試,比照 System/map/map_system.gd 的 pick_object()。跟地圖不同
## 的是每棟建築一定有 territory_polygon(見 BuildingLibrary.get_all(),使用者在原圖上
## 手繪的建築外框),不需要 MapSystem 那套「沒有 polygon 就退回半徑最近命中」的 fallback。
## 不處理畫面/攝影機。


func pick_building(world_pos: Vector2, buildings: Array[Building]) -> Building:
	for building in buildings:
		if Geometry2D.is_point_in_polygon(world_pos, building.territory_polygon):
			return building
	return null
