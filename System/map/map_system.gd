class_name MapSystem
extends RefCounted

## 大地圖移動邏輯:移動速度計算、逐幀逼近目的地、點擊命中測試。
## 不處理世界時間(見 System/time/world_time.gd)、不處理畫面(見 Scenes/Map/map.gd)。

## 地圖固定尺寸(world unit)。與視窗 1600x900 同為 16:9,方便縮放換算。
const MAP_SIZE := Vector2(8000.0, 4500.0)

## sqrt(MAP_SIZE.x^2 + MAP_SIZE.y^2)。GDScript 的 const 運算式不能呼叫
## Vector2.length()/sqrt(),因此手算後寫成字面常數;MAP_SIZE 若日後調整
## 記得手動重算這個值。
const MAP_DIAGONAL := 9178.693649053699

## 左上→左下(垂直距離 MAP_SIZE.y),平均 AGI 200 時需 90 秒
const SPEED_AT_AGI_200 := MAP_SIZE.y / 90.0

## 左上→右下(對角線距離 MAP_DIAGONAL),平均 AGI 0 時需 360 秒
const SPEED_AT_AGI_0 := MAP_DIAGONAL / 360.0

## 玩家速度調整值 讓玩家比地圖上敵人快 20% 後面可以被科技升級 
const PLAYER_SPEED_MULTIPLIER = 1.2

var position: Vector2
var target_position: Vector2
var is_moving: bool = false
var speed: float
## 抵達 target_position 之後接著要走的後續路徑點(見 MapPathfinder.find_path()),
## set_destination() 的單點直線移動不會用到,固定是空陣列。
var path_queue: Array[Vector2] = []


func _init(p_start_position: Vector2, p_speed: float) -> void:
	position = p_start_position
	target_position = p_start_position
	speed = p_speed


## Party 全體成員的平均 AGI(0~200),用 character.agility(等級加成後的算後值),
## 不是 character.potential.agility(未加成的原始值)。
static func compute_average_agi(party: Party) -> float:
	if party == null or party.characteres.is_empty():
		return 0.0
	var total := 0.0
	for character in party.characteres:
		total += character.agility
	return clamp(total / party.characteres.size(), 0.0, 200.0)


## AGI 0~200 之間線性內插移動速度。
static func compute_speed(avg_agi: float) -> float:
	var clamped: float = clamp(avg_agi, 0.0, 200.0)
	return lerp(SPEED_AT_AGI_0, SPEED_AT_AGI_200, clamped / 200.0) * PLAYER_SPEED_MULTIPLIER


func set_destination(p_target: Vector2) -> void:
	target_position = p_target
	path_queue.clear()
	is_moving = true


## 依序走訪一串路徑點(見 MapPathfinder.find_path()):第一個點設為目前 target_position,
## 其餘存進 path_queue 接力,advance() 抵達每個中繼點時自動切換下一個,直到 path_queue
## 淨空才真正停止(is_moving=false)。傳空陣列不做任何事(呼叫端應自行 fallback,不會
## 走到這裡)。
func set_path(waypoints: Array[Vector2]) -> void:
	if waypoints.is_empty():
		return
	path_queue = waypoints.duplicate()
	target_position = path_queue.pop_front()
	is_moving = true


## 每 frame 呼叫,依目前速度 x delta 逐幀逼近目的地,從不預先計算/寫死
## 某段路線該花多久——移動時間永遠等於「距離 / 速度」的自然結果。用 while 迴圈消耗這一幀
## 的可走距離,而不是每幀只處理一個 target_position:高倍速(DEMO 100x)或路徑點很密集時,
## 一幀走的距離可能一口氣超過好幾個路徑點,不這樣寫會卡在中繼點多等好幾幀才繼續前進。
func advance(delta: float) -> void:
	if not is_moving:
		return
	var remaining := speed * delta
	while remaining > 0.0 and is_moving:
		var to_target := target_position - position
		var dist := to_target.length()
		if dist < 0.001:
			position = target_position
		elif remaining >= dist:
			position = target_position
			remaining -= dist
		else:
			position += to_target.normalized() * remaining
			remaining = 0.0
			continue

		if not path_queue.is_empty():
			target_position = path_queue.pop_front()
		else:
			is_moving = false


## 找出 world_pos 命中的 MapObject:有 territory_polygon 的物件用多邊形範圍
## 判定(整塊領土都能點),沒有的物件才退回用 position 附近 radius 內最近命中。
## 找不到回傳 null。
func pick_object(world_pos: Vector2, objects: Array[MapObject], radius: float) -> MapObject:
	for obj in objects:
		if not obj.territory_polygon.is_empty() and Geometry2D.is_point_in_polygon(world_pos, obj.territory_polygon):
			return obj

	var closest: MapObject = null
	var closest_dist := radius
	for obj in objects:
		if not obj.territory_polygon.is_empty():
			continue
		var d := obj.position.distance_to(world_pos)
		if d <= closest_dist:
			closest_dist = d
			closest = obj
	return closest
