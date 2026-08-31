class_name RhythmBeatIndicator
extends Control

## 節奏預測圈畫面元件:固定圓(目標圈)+ 每個正確譜節點各自一顆等速縮小圓,縮放比例算法見
## System/rhythm/rhythm_beat_predictor.gd。連打段落(多個節點時間相近)會同時畫出多顆縮小圓
## 各自朝固定圓收斂,不合併成一顆。RhythmPlayView 只有在建築缺角色動作圖素材
## (_character_textures 為空)時才會建立這塊區域取代動畫,見該檔 _build_layout()。

const TARGET_RADIUS := 50.0
const START_RADIUS := 150.0
const RING_WIDTH := 4.0
const TARGET_COLOR := Color(0.85, 0.75, 0.35)
const SHRINK_COLOR := Color(1.0, 1.0, 1.0, 0.85)
const ARC_POINT_COUNT := 64

var _fractions: Array[float] = []


func _ready() -> void:
	custom_minimum_size = Vector2(START_RADIUS, START_RADIUS) * 2.0


## RhythmPlayView._process() 每幀呼叫,beats 傳玩家正確譜(跟角色動作圖同一套時間軸,
## 不是提示音的時間戳)。
func update_time(t: float, beats: Array[float]) -> void:
	_fractions = RhythmBeatPredictor.active_fractions_for(t, beats)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	draw_arc(center, TARGET_RADIUS, 0.0, TAU, ARC_POINT_COUNT, TARGET_COLOR, RING_WIDTH, true)
	for fraction in _fractions:
		var radius: float = lerpf(START_RADIUS, TARGET_RADIUS, fraction)
		draw_arc(center, radius, 0.0, TAU, ARC_POINT_COUNT, SHRINK_COLOR, RING_WIDTH, true)
