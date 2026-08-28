class_name TravelEventRoller
extends RefCounted

## 大地圖移動中「旅行事件」(見 System/event/map/travel/)的觸發節流器。跟
## RoamingEnemySpawner 的格子生成不同——旅行事件沒有留在地圖上的實體,骰到就立刻觸發、
## 播完就沒了,不需要記住「哪個格子骰過」來防止重複觸發,所以改用「累積移動距離,滿一段
## 就骰一次」這種更簡單的計步器模型,骰完不管中不中都馬上歸零重新累積,永遠可以再次觸發。

const DISTANCE_PER_ROLL := 1000.0
const TRIGGER_CHANCE := 0

var _distance_since_last_roll: float = 0.0
var _last_player_pos: Vector2
## sentinel:第一次呼叫 check() 只用來記錄起始座標,不能拿「起點到第一幀移動後座標」的
## 距離就計進累積值,否則會把玩家剛出生的座標誤算成一段移動。
var _has_last_pos: bool = false


## map.gd 每幀移動時呼叫(只在 map_system.is_moving 時呼叫,見 map.gd 註解)。回傳這一次
## 是否要觸發旅行事件。
func check(player_pos: Vector2) -> bool:
	if not _has_last_pos:
		_has_last_pos = true
		_last_player_pos = player_pos
		return false

	_distance_since_last_roll += player_pos.distance_to(_last_player_pos)
	_last_player_pos = player_pos
	if _distance_since_last_roll < DISTANCE_PER_ROLL:
		return false

	_distance_since_last_roll = 0.0
	return Util.get_random_float(0.0, 1.0) <= TRIGGER_CHANCE
