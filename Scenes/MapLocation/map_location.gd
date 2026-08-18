extends Control

## 泛用的「地點選單」畫面:抵達大地圖上的某個 MapObject 後顯示,顯示哪個地點、
## 有哪些子選項完全由該地點的資料決定(見 System/map/map_object.gd 的
## get_sub_locations()),這裡不寫死任何特定地點類型(城鎮/村莊/遺跡等)的語意。

## 目前接了真實行為的子地點按鈕文字(見 System/map/map_object.gd 的
## TYPE_SUB_LOCATIONS),其餘子地點還是空按鈕佔位。
const TOWN_LABEL := "城門"
const CHAT_LABEL := "聊天"
const TAVERN_LABEL := "酒館"
const REST_LABEL := "休息"
const ENTER_BASE_LABEL := "進入根據地"

## 地點選單按鈕統一套木牌鐵框樣式(UiStyle.apply_wood_plaque_button),margin 比
## main.tscn 的 Start 按鈕縮小一截——這裡最多要疊 5、6 顆按鈕,用 Start 那組大 margin
## 會把整個選單撐出畫面。
const SUB_LOCATION_BUTTON_MIN_SIZE := Vector2(260, 84)
const SUB_LOCATION_CONTENT_MARGIN_H := 40.0
const SUB_LOCATION_CONTENT_MARGIN_V := 20.0

@onready var background: TextureRect = $Background
@onready var title_label: Label = $CenterContainer/VBoxContainer/TitleLabel
@onready var sub_locations_container: VBoxContainer = $CenterContainer/VBoxContainer/SubLocationsContainer
@onready var leave_button: Button = $CenterContainer/VBoxContainer/LeaveButton

var _map_object: MapObject


func _ready() -> void:
	_style_sub_location_button(leave_button)

	_map_object = _find_entered_map_object()
	if _map_object == null:
		# 防呆:不是從 Scenes/Map/map.gd 的正常流程進來(例如直接開這個場景測試)。
		title_label.text = "（無地點資料）"
		return

	title_label.text = _map_object.name
	_update_background()
	for sub_location_label in MapObject.get_sub_locations(_map_object.type):
		var button := Button.new()
		button.text = sub_location_label
		_style_sub_location_button(button)
		if sub_location_label == TOWN_LABEL:
			button.pressed.connect(_on_town_button_pressed)
		elif sub_location_label == CHAT_LABEL:
			button.pressed.connect(_on_chat_button_pressed)
		elif sub_location_label == TAVERN_LABEL:
			button.pressed.connect(_on_tavern_button_pressed)
		elif sub_location_label == REST_LABEL:
			button.pressed.connect(_on_rest_button_pressed)
		elif sub_location_label == ENTER_BASE_LABEL:
			button.pressed.connect(_on_enter_base_button_pressed)
		sub_locations_container.add_child(button)


## 整頁背景圖:TOWN 依 _map_object.terrain_type() 挑對應地形的城鎮圖(每座城鎮代表
## 各自文明的地形特色),BASE 固定用同一張(玩家還沒有可選的自身國家血統)。跟
## TownChatEvent 的 Dialogue 背景是同一張圖、不同用途,共用 GameEnums 的路徑組字函式。
func _style_sub_location_button(button: Button) -> void:
	button.custom_minimum_size = SUB_LOCATION_BUTTON_MIN_SIZE
	UiStyle.apply_wood_plaque_button(button, SUB_LOCATION_CONTENT_MARGIN_H, SUB_LOCATION_CONTENT_MARGIN_V)


func _update_background() -> void:
	var path: String
	match _map_object.type:
		GameEnums.MapObjectType.TOWN:
			path = GameEnums.town_background_path(_map_object.terrain_type())
		GameEnums.MapObjectType.BASE:
			path = GameEnums.BASE_LOCATION_BACKGROUND_PATH
		_:
			return
	background.texture = load(path) as Texture2D


func _find_entered_map_object() -> MapObject:
	for obj in MapObject.get_all():
		if obj.id == MapSessionStore.entered_map_object_id:
			return obj
	return null


## 城門守衛擋門 → 戰鬥 → 依勝負反應,整段流程(對話文案/AskBattle 詢問/戰報回傳)
## 全部交給 System/event/town/town_gate_event.gd 的 TownGateEvent 接管,這裡只
## 負責告訴它事件結束後要回哪個場景(這個地點選單本身)。
func _on_town_button_pressed() -> void:
	TownGateEvent.trigger("res://Scenes/MapLocation/map_location.tscn")


## 隨機村民聊天,同樣整段交給 System/event/town/town_chat_event.gd 的
## TownChatEvent 接管,聊完回到這個地點選單本身。背景圖固定用住宅區場景,不分地形。
func _on_chat_button_pressed() -> void:
	TownChatEvent.trigger("res://Scenes/MapLocation/map_location.tscn")


## 酒館搭訕,整段交給 System/event/town/town_tavern_event.gd 的 TownTavernEvent
## 接管,結束後回到這個地點選單本身。
func _on_tavern_button_pressed() -> void:
	TownTavernEvent.trigger("res://Scenes/MapLocation/map_location.tscn")


## 進入根據地:直接切去 Scenes/Base/base.tscn,不經過任何過場對話(建築內政的實際
## 邏輯/畫面都在那個場景,這裡只負責入口)。MapSessionStore.entered_map_object_id
## 不需要清掉——base.gd 的「離開」按鈕會直接回到這個地點選單頁,還原時一樣讀得到
## 「根據地」。
func _on_enter_base_button_pressed() -> void:
	var error := get_tree().change_scene_to_file("res://Scenes/Base/base.tscn")
	if error != OK:
		printerr("Error changing scene to base: ", error)


## 離開:退回大地圖並暫停時間,跟 Scenes/Map/map.gd 抵達地點時反過來暫停
## (_handle_click_to_move()/_process() 的 WorldTimeStore.controller.is_playing = false)
## 對稱——不這樣主動關掉的話,若玩家在根據地/這個選單按過空白鍵切成播放中(HeaderBar
## 在這幾個場景都掛著,見 Scripts/UI/header_bar.gd),回到大地圖會發現時間憑空偷跑。
func _on_leave_button_pressed() -> void:
	WorldTimeStore.controller.is_playing = false
	var error := get_tree().change_scene_to_file("res://Scenes/Map/map.tscn")
	if error != OK:
		printerr("Error changing scene to map: ", error)


## 休息:退回大地圖並直接開始播放時間(不用玩家手動按空白鍵),讓世界時間流逝
## 帶動 WorldTimeEventLibrary 的每日角色回血。WorldTimeStore 是應用程式全程存活的
## autoload,切場景不會重置,直接改 controller.is_playing 就會帶到下一個場景,不需要
## 經過 MapSessionStore 交接。額外設 MapSessionStore.rest_requested,map.gd._ready()
## 讀到後會把玩家頭像藏起來、暫停撞遊蕩敵人判定(見該檔案的 _is_resting)——不這樣做
## 的話,玩家角色會原地站在城鎮/根據地座標上被路過的遊蕩敵人撞上觸發戰鬥,「休息」
## 卻反而挨打。
func _on_rest_button_pressed() -> void:
	WorldTimeStore.controller.is_playing = true
	MapSessionStore.rest_requested = true
	var error := get_tree().change_scene_to_file("res://Scenes/Map/map.tscn")
	if error != OK:
		printerr("Error changing scene to map: ", error)
