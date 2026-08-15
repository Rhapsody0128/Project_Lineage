class_name MapSystem
extends RefCounted

## 大地圖移動邏輯:移動速度計算、逐幀逼近目的地、點擊命中測試。
## 不處理世界時間(見 WorldTime.gd)、不處理畫面(見 Scenes/Map/map.gd)。

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

var position: Vector2
var target_position: Vector2
var is_moving: bool = false
var speed: float


func _init(p_start_position: Vector2, p_speed: float) -> void:
	position = p_start_position
	target_position = p_start_position
	speed = p_speed


## Party 全體成員的平均 AGI(0~200),用 hero.agility(等級加成後的算後值),
## 不是 hero.potential.agility(未加成的原始值)。
static func compute_average_agi(party: Party) -> float:
	if party == null or party.heroes.is_empty():
		return 0.0
	var total := 0.0
	for hero in party.heroes:
		total += hero.agility
	return clamp(total / party.heroes.size(), 0.0, 200.0)


## AGI 0~200 之間線性內插移動速度。
static func compute_speed(avg_agi: float) -> float:
	var clamped: float = clamp(avg_agi, 0.0, 200.0)
	return lerp(SPEED_AT_AGI_0, SPEED_AT_AGI_200, clamped / 200.0)


func set_destination(p_target: Vector2) -> void:
	target_position = p_target
	is_moving = true


## 每 frame 呼叫,依目前速度 x delta 逐幀逼近目的地,從不預先計算/寫死
## 某段路線該花多久——移動時間永遠等於「距離 / 速度」的自然結果。
func advance(delta: float) -> void:
	if not is_moving:
		return
	var to_target := target_position - position
	var dist := to_target.length()
	var step := speed * delta
	if step >= dist or dist < 0.001:
		position = target_position
		is_moving = false
	else:
		position += to_target.normalized() * step


## 找出 world_pos 附近 radius 內最近的 MapObjectData,找不到回傳 null。
func pick_object(world_pos: Vector2, objects: Array[MapObjectData], radius: float) -> MapObjectData:
	var closest: MapObjectData = null
	var closest_dist := radius
	for obj in objects:
		var d := obj.position.distance_to(world_pos)
		if d <= closest_dist:
			closest_dist = d
			closest = obj
	return closest
