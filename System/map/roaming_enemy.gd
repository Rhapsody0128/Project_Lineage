class_name RoamingEnemy
extends RefCounted

## 大地圖上單一隻遊蕩敵人的資料 + 遊蕩移動狀態。比照 MapObject 是純資料的精神,但敵人
## 的 position 會變動(原地小範圍隨機遊蕩),所以額外帶了遊蕩用的計時器欄位。生成規則
## (何時生成/消失)不在這裡,見 RoamingEnemySpawner。

## 遊蕩範圍半徑(world unit,以 anchor 為圓心)——不是以目前 position 為圓心,避免每次
## 都往同個方向續走導致越漂越遠。
# 220原本
const WANDER_RADIUS := 500.0
const WANDER_PAUSE_MIN := 1.0
const WANDER_PAUSE_MAX := 3.0
## 位移小於這個長度視為「沒有在走」,畫面端用來判斷該播 idle 還是 walk 動畫。
const MOVE_EPSILON := 0.5

var id: String
var position: Vector2
## 生成點,遊蕩範圍以此為中心;敵人被移除時不需要用到,純粹是遊蕩時的錨點。
var anchor: Vector2
## 生成當下就 roll 好一支完整隊伍,固定到敵人消失為止,不會每次戰鬥重骰。
var party: Party
## GameEnums.RankType,顯示用標籤,直接沿用生成當下的 party.rank_type
## (見 RoamingEnemySpawner._try_spawn_in_cell())。
var rank: int
## 遊蕩移動速度:比照玩家(MapSystem.compute_average_agi()/compute_speed()),用
## 這支敵人隊伍的平均 AGI 換算,不是寫死的常數——隊伍骰出來就固定,跟 party 一樣
## 不會變動。
var wander_speed: float

var _wander_target: Vector2
var _is_paused: bool = true
var _pause_timer: float = 0.0


func _init(p_id: String, p_position: Vector2, p_party: Party, p_rank: int) -> void:
	id = p_id
	position = p_position
	anchor = p_position
	party = p_party
	rank = p_rank
	wander_speed = MapSystem.compute_speed(MapSystem.compute_average_agi(p_party))
	_pause_timer = Util.get_random_float(WANDER_PAUSE_MIN, WANDER_PAUSE_MAX)


## 每幀呼叫,推進原地遊蕩;回傳這一步的位移量(Vector2.ZERO 代表沒有移動),
## 供畫面端判斷走路方向/播放對應動畫。
func advance_wander(delta: float) -> Vector2:
	if _is_paused:
		_pause_timer -= delta
		if _pause_timer <= 0.0:
			_is_paused = false
			var raw_target := anchor + Vector2(Util.get_random_float(-WANDER_RADIUS, WANDER_RADIUS), Util.get_random_float(-WANDER_RADIUS, WANDER_RADIUS))
			# 夾在地圖範圍內——anchor 本身在生成時就已經夾過(見 RoamingEnemySpawner.
			# _try_spawn_in_cell()),position 永遠在地圖內,只要 _wander_target 也夾在
			# 範圍內,兩點之間直線移動必然全程不出界(矩形是凸集合)。不夾的話 anchor
			# 靠近地圖邊緣時,加上 WANDER_RADIUS(1800)偏移很容易算出地圖外的座標,敵人
			# (以及跟著牠追過去的玩家,見 map.gd 的 _traveling_to_enemy 追蹤同步)就會被
			# 帶出地圖。
			_wander_target = Vector2(
				clamp(raw_target.x, 0.0, MapSystem.MAP_SIZE.x),
				clamp(raw_target.y, 0.0, MapSystem.MAP_SIZE.y)
			)
		return Vector2.ZERO

	var to_target := _wander_target - position
	var dist := to_target.length()
	var step := wander_speed * delta
	if step >= dist or dist < MOVE_EPSILON:
		var move_delta := _wander_target - position
		position = _wander_target
		_is_paused = true
		_pause_timer = Util.get_random_float(WANDER_PAUSE_MIN, WANDER_PAUSE_MAX)
		return move_delta

	var move_delta := to_target.normalized() * step
	position += move_delta
	return move_delta
