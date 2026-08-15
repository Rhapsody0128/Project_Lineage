extends Node

# =========================================================
# 大地圖離開/返回用的狀態交接點(autoload,見 project.godot)。跟 BattleReportStore/
# PartyEditStore 同一套「mailbox」模式:Scenes 層的 session 狀態,不是規則邏輯,
# 所以放 Scripts/Autoload/ 不放 System/。
#
# Map.tscn 抵達地點時整個 change_scene_to_file 切去 Scenes/MapLocation/,場景樹會
# 被整個換掉、map.gd 的節點狀態(MapSystem/WorldTime/相機 zoom)全部消失,所以離開前
# 把這些值存進這裡,回到 Map.tscn 的 _ready() 再讀出來還原,而不是重新從出生點/
# B.C.621 年開始。entered_map_object_id 身兼「這次要進哪個地點」的交接欄位——
# 存檔當下玩家一定正站在那個地點上,不需要另外拆一個欄位。
# =========================================================

var has_saved_state: bool = false
var player_position: Vector2
var day_accumulator: float
var camera_zoom: Vector2
var is_playing: bool
var entered_map_object_id: String


func save_map_state(p_position: Vector2, p_day_accumulator: float, p_camera_zoom: Vector2, p_is_playing: bool, p_map_object_id: String) -> void:
	player_position = p_position
	day_accumulator = p_day_accumulator
	camera_zoom = p_camera_zoom
	is_playing = p_is_playing
	entered_map_object_id = p_map_object_id
	has_saved_state = true
