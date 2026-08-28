class_name MapPathfinder
extends RefCounted

## 大地圖路徑規劃:點擊移動原本只算「目前位置→目的地」的直線,中途若剛好穿過山岳鏤空/
## 海面等不可行走區域一樣會被直接穿過去——地形邊界不是凸集合,直線終點落在陸地上不保證
## 整條路徑都在陸地上(見 MapTerrainMask.clamp_segment_to_walkable() 的已知簡化)。這裡在
## MapTerrainMask 的色塊 mask 上鋪一層網格跑 AStarGrid2D,算出一條繞開不可行走區域的路徑,
## 再用「拉直線」(string pulling)精簡成轉折點更少、貼近真正最短距離的折線,取代單一
## 直線目標交給 MapSystem.set_path() 逐段前進。

## 網格單一格邊長(world unit)。MapSystem.MAP_SIZE 是 8000x4500,地形色塊(山岳鏤空/
## 海岸線)都是大範圍區塊,不存在窄於這個尺寸的通道,不需要比 mask 圖片
## (Images/Map/map_terrain.png,5440x3072)解析度更細的網格。
const CELL_SIZE := 50.0

## 起訖點卡在不可行走格(mask 邊界抗鋸齒誤差、或目的地本身是山岳鏤空/海面)時,向外
## 螺旋找最近可行走格頂替的搜尋半徑(格數)。全地圖不可行走區域都連著一大片海/山,
## 理論上不會需要搜到這麼遠。
const RESOLVE_SEARCH_RADIUS := 20

## 折線精簡(_simplify_path())判斷「兩點之間是否整段可行走」時的抽樣間隔,設比
## CELL_SIZE 小一些,避免抽樣間距剛好跳過中間一整格不可行走的區域。
const LINE_CHECK_STEP := CELL_SIZE * 0.5

## 靜態快取,整個執行期間只建一次網格(建網格要對每一格呼叫一次 MapTerrainMask.
## is_walkable(),跟 MapTerrainMask._image 一樣沒必要重算)。
static var _grid: AStarGrid2D = null


static func _get_grid() -> AStarGrid2D:
	if _grid == null:
		_grid = AStarGrid2D.new()
		var size := Vector2i(ceili(MapSystem.MAP_SIZE.x / CELL_SIZE), ceili(MapSystem.MAP_SIZE.y / CELL_SIZE))
		_grid.region = Rect2i(Vector2i.ZERO, size)
		_grid.cell_size = Vector2(CELL_SIZE, CELL_SIZE)
		# 只有在對角兩側都沒有障礙物時才允許斜走,避免路徑貼著山岳/海岸邊角穿過去。
		_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
		_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
		_grid.update()
		for y in range(size.y):
			for x in range(size.x):
				var cell := Vector2i(x, y)
				if not MapTerrainMask.is_walkable(_grid.get_point_position(cell)):
					_grid.set_point_solid(cell)
	return _grid


static func _world_to_cell(pos: Vector2) -> Vector2i:
	var grid := _get_grid()
	return Vector2i(
		clampi(int(pos.x / CELL_SIZE), 0, grid.region.size.x - 1),
		clampi(int(pos.y / CELL_SIZE), 0, grid.region.size.y - 1)
	)


## 算出 from_pos → to_pos 之間繞過不可行走區域的路徑,回傳「接下來要依序走到」的世界座標
## 折線(不含 from_pos 本身,含終點)。to_pos 本身若不可行走(點在海上/山岳鏤空),終點會
## 頂替成離它最近的可行走點,比照舊版 clamp_segment_to_walkable() 的「目的地卡在陸地範圍
## 內」行為。起訖點分屬不連通區域(例如隔著海洋的兩塊陸地)時回傳空陣列,呼叫端(見
## Scenes/Map/map.gd 的 _plan_route())fallback 成舊版直線 + 邊界夾住的簡化行為。
static func find_path(from_pos: Vector2, to_pos: Vector2) -> Array[Vector2]:
	var grid := _get_grid()
	var raw_to_cell := _world_to_cell(to_pos)
	var to_pos_walkable := not grid.is_point_solid(raw_to_cell)

	var from_cell := _resolve_walkable_cell(_world_to_cell(from_pos))
	var to_cell := _resolve_walkable_cell(raw_to_cell)
	if from_cell == Vector2i(-1, -1) or to_cell == Vector2i(-1, -1):
		return []

	var final_point := to_pos if to_pos_walkable else grid.get_point_position(to_cell)
	if from_cell == to_cell:
		return [final_point]

	var cell_path := grid.get_id_path(from_cell, to_cell)
	if cell_path.is_empty():
		return []

	var waypoints: Array[Vector2] = [from_pos]
	for cell in cell_path:
		waypoints.append(grid.get_point_position(cell))
	waypoints[waypoints.size() - 1] = final_point
	return _simplify_path(waypoints)


static func _resolve_walkable_cell(cell: Vector2i) -> Vector2i:
	var grid := _get_grid()
	if not grid.is_point_solid(cell):
		return cell
	for radius in range(1, RESOLVE_SEARCH_RADIUS + 1):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var c := Vector2i(cell.x + dx, cell.y + dy)
				if grid.region.has_point(c) and not grid.is_point_solid(c):
					return c
	return Vector2i(-1, -1)


## 折線精簡(string pulling):從起點開始,每一步盡量找「直線可達且整段可行走」的最遠
## 一個路徑點直接連過去,跳過中間共線/近似共線的網格轉折,讓路徑貼近真正最短距離,
## 而不是網格對角線的鋸齒狀走法。回傳陣列不含起點(waypoints[0]),終點固定是呼叫端
## 已覆寫過的 final_point。
static func _simplify_path(waypoints: Array[Vector2]) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var anchor_index := 0
	while anchor_index < waypoints.size() - 1:
		var farthest := anchor_index + 1
		for j in range(waypoints.size() - 1, anchor_index, -1):
			if _line_is_walkable(waypoints[anchor_index], waypoints[j]):
				farthest = j
				break
		result.append(waypoints[farthest])
		anchor_index = farthest
	return result


## 沿線段抽樣檢查是否整段可行走,直接查網格 solid 狀態(而非重新比對 mask 顏色),
## 抽樣次數雖多但都是既有網格資料的查表,成本很低。
static func _line_is_walkable(a: Vector2, b: Vector2) -> bool:
	var grid := _get_grid()
	var dist := a.distance_to(b)
	var steps := maxi(1, ceili(dist / LINE_CHECK_STEP))
	for s in range(steps + 1):
		var t := float(s) / float(steps)
		if grid.is_point_solid(_world_to_cell(a.lerp(b, t))):
			return false
	return true
