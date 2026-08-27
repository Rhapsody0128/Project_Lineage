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
#
# rest_requested 是 Scenes/MapLocation/map_location.gd 的「休息」按鈕切回 map.tscn 前
# 設的一次性旗標,map.gd._ready() 讀到後轉成 is_resting 狀態(把玩家頭像藏起來、暫停
# 撞遊蕩敵人判定),讀完立刻清成 false——跟 has_saved_state 不同,這個旗標不需要
# 「有沒有存過」的概念,預設 false 本身就是合法的「沒有要休息」狀態。
#
# is_resting 則是持續有效的「目前是否正在休息」狀態,map.gd 醒來時(玩家主動點地圖
# 移動,見 _end_resting())會改回 false。放在這裡而不是 map.gd 的場景私有變數,是因為
# System/time/world_time_event_library.gd 的每日回血結算需要讀這個值(休息中額外加成,
# 見 Character.RESTING_HP_REGEN_BONUS)——比照 AgingRule 呼叫 BaseBuildingProgressStore
# 的既有慣例,System 不直接碰 Scenes 節點,只讀 autoload 暴露的狀態。
#
# long_rest_target_day 是「長休」(BASE 專屬,見 Scenes/MapLocation/map_location.gd 的
# LONG_REST_LABEL)專用的一次性目標:玩家在長休面板指定天數後,這裡存下
# WorldTimeController.world_time.get_day_count() 的目標值(-1 代表目前沒有長休倒數中)。
# map.gd 接 WorldTimeStore.day_passed 訊號逐日比對,天數到達時跟玩家提早移動
# (_end_resting())一樣把倍速還原成 1 倍、清回 -1——長休倒數的「目前正在休息」畫面效果
# (頭像隱藏/跳過撞遊蕩敵人判定)仍是共用同一個 is_resting,不需要另開一套。
# =========================================================

var has_saved_state: bool = false
var player_position: Vector2
var target_position: Vector2
var is_moving: bool
var camera_position: Vector2
var camera_zoom: Vector2
var entered_map_object_id: String
var traveling_to_map_object_id: String
var rest_requested: bool = false
var is_resting: bool = false
var long_rest_target_day: int = -1


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


## 存檔用:玩家在地圖上的座標一併存進存檔,讀檔後才不會被丟回出生點(見
## Scenes/Map/map.gd 的 _sync_session_state(),每幀都同步這裡,不用等離開地圖場景
## 才存一次)。has_saved_state 還是 false(這次執行期玩家從沒進過地圖,或存檔當下
## 是還沒編過隊的全新遊戲)時不存任何座標,讀檔後維持 map.gd _ready() 原本的預設出生點
## 邏輯。
func to_save_data() -> Dictionary:
	if not has_saved_state:
		return {}
	return {
		"player_position": [player_position.x, player_position.y],
		"target_position": [target_position.x, target_position.y],
		"is_moving": is_moving,
		"camera_position": [camera_position.x, camera_position.y],
		"camera_zoom": [camera_zoom.x, camera_zoom.y],
		"entered_map_object_id": entered_map_object_id,
		"traveling_to_map_object_id": traveling_to_map_object_id,
	}


func load_save_data(data: Dictionary) -> void:
	if data.is_empty():
		has_saved_state = false
		return
	var pp: Array = data["player_position"]
	var tp: Array = data["target_position"]
	var cp: Array = data["camera_position"]
	var cz: Array = data["camera_zoom"]
	save_map_state(
		Vector2(pp[0], pp[1]),
		Vector2(tp[0], tp[1]),
		data.get("is_moving", false),
		Vector2(cp[0], cp[1]),
		Vector2(cz[0], cz[1]),
		data.get("entered_map_object_id", ""),
		data.get("traveling_to_map_object_id", "")
	)
