extends Node

# =========================================================
# 大地圖離開/返回用的狀態交接點(autoload,見 project.godot)。跟 BattleReportStore/
# PartyStore 同一套「mailbox」模式:Scenes 層的 session 狀態,不是規則邏輯,
# 所以放 Scripts/Autoload/ 不放 System/。
#
# 離開 Scenes/Map/map.tscn 時(不管是抵達地點切去 Scenes/MapLocation/,還是從
# HeaderBar 選單切去戰報/隊伍編輯),整個場景樹會被換掉,map.gd 的節點狀態
# (MapSystem/WorldTime/相機 zoom/移動目標)全部消失,所以 map.gd 的 _exit_tree()
# 一律把這些值存進這裡,回到 map.tscn 的 _ready() 再讀出來還原,而不是重新從
# 出生點/B.C.621 年開始、或是弄丟正在進行中的移動。entered_map_object_id 身兼
# 「這次要進哪個地點」的交接欄位給 map_location.gd 讀——存檔當下玩家一定正站在
# 那個地點上,不需要另外拆一個欄位。traveling_to_map_object_id 則是「正走去哪個
# 地點」,用來在移動途中離開/返回時還原 map.gd 的 _traveling_to,抵達時才能正確
# 觸發 _enter_map_object()。
# =========================================================

var has_saved_state: bool = false
var player_position: Vector2
var target_position: Vector2
var is_moving: bool
var day_accumulator: float
var camera_position: Vector2
var camera_zoom: Vector2
var is_playing: bool
var entered_map_object_id: String
var traveling_to_map_object_id: String


func save_map_state(
	p_position: Vector2,
	p_target_position: Vector2,
	p_is_moving: bool,
	p_day_accumulator: float,
	p_camera_position: Vector2,
	p_camera_zoom: Vector2,
	p_is_playing: bool,
	p_map_object_id: String,
	p_traveling_to_map_object_id: String
) -> void:
	player_position = p_position
	target_position = p_target_position
	is_moving = p_is_moving
	day_accumulator = p_day_accumulator
	camera_position = p_camera_position
	camera_zoom = p_camera_zoom
	is_playing = p_is_playing
	entered_map_object_id = p_map_object_id
	traveling_to_map_object_id = p_traveling_to_map_object_id
	has_saved_state = true


## 目前世界曆法時間的顯示字串,供戰報/戰鬥畫面當標題用(見 battle.gd、
## battle_report_store.gd)。還沒踏進過大地圖時 day_accumulator 是預設值 0.0,
## 對應曆法起點,不需要另外防呆。
func current_world_time_string() -> String:
	return WorldTime.new(1.0, day_accumulator).get_display_string()
