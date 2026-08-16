extends Node

# =========================================================
# 大地圖離開/返回用的狀態交接點(autoload,見 project.godot)。跟 BattleReportStore/
# PartyStore 同一套「mailbox」模式:Scenes 層的 session 狀態,不是規則邏輯,
# 所以放 Scripts/Autoload/ 不放 System/。
#
# 離開 Scenes/Map/map.tscn 時(不管是抵達地點切去 Scenes/MapLocation/,還是從
# HeaderBar 選單切去戰報/隊伍編輯),整個場景樹會被換掉,map.gd 的節點狀態
# (MapSystem/相機 zoom/移動目標)全部消失,所以 map.gd 的 _exit_tree() 一律把
# 這些值存進這裡,回到 map.tscn 的 _ready() 再讀出來還原,而不是重新從出生點
# 開始、或是弄丟正在進行中的移動。entered_map_object_id 身兼「這次要進哪個地點」
# 的交接欄位給 map_location.gd 讀——存檔當下玩家一定正站在那個地點上,不需要
# 另外拆一個欄位。traveling_to_map_object_id 則是「正走去哪個地點」,用來在移動
# 途中離開/返回時還原 map.gd 的 _traveling_to,抵達時才能正確觸發
# _enter_map_object()。
#
# 世界時間(曆法/是否播放中)不在這裡——那是 WorldTimeStore autoload 全程持有的
# 狀態(見 Scripts/Autoload/world_time_store.gd),離開/返回地圖不會重置,不需要
# 手動存讀。
# =========================================================

var has_saved_state: bool = false
var player_position: Vector2
var target_position: Vector2
var is_moving: bool
var camera_position: Vector2
var camera_zoom: Vector2
var entered_map_object_id: String
var traveling_to_map_object_id: String


func save_map_state(
	p_position: Vector2,
	p_target_position: Vector2,
	p_is_moving: bool,
	p_camera_position: Vector2,
	p_camera_zoom: Vector2,
	p_map_object_id: String,
	p_traveling_to_map_object_id: String
) -> void:
	player_position = p_position
	target_position = p_target_position
	is_moving = p_is_moving
	camera_position = p_camera_position
	camera_zoom = p_camera_zoom
	entered_map_object_id = p_map_object_id
	traveling_to_map_object_id = p_traveling_to_map_object_id
	has_saved_state = true
