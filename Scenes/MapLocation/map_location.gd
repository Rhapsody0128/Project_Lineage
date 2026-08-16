extends Control

## 泛用的「地點選單」畫面:抵達大地圖上的某個 MapObjectData 後顯示,顯示哪個地點、
## 有哪些子選項完全由該地點的資料決定(見 System/Map/MapObjectData.gd 的
## get_sub_locations()),這裡不寫死任何特定地點類型(城堡/村莊/遺跡等)的語意。

## 目前接了真實行為的子地點按鈕文字(見 System/Map/MapObjectData.gd 的
## TYPE_SUB_LOCATIONS),其餘子地點還是空按鈕佔位。
const CASTLE_LABEL := "城堡"
const CHAT_LABEL := "聊天"
const REST_LABEL := "休息"

@onready var title_label: Label = $CenterContainer/VBoxContainer/TitleLabel
@onready var sub_locations_container: VBoxContainer = $CenterContainer/VBoxContainer/SubLocationsContainer

var _map_object: MapObjectData


func _ready() -> void:
	_map_object = _find_entered_map_object()
	if _map_object == null:
		# 防呆:不是從 Scenes/Map/map.gd 的正常流程進來(例如直接開這個場景測試)。
		title_label.text = "（無地點資料）"
		return

	title_label.text = _map_object.name
	for sub_location_label in MapObjectData.get_sub_locations(_map_object.type):
		var button := Button.new()
		button.text = sub_location_label
		if sub_location_label == CASTLE_LABEL:
			button.pressed.connect(_on_castle_button_pressed)
		elif sub_location_label == CHAT_LABEL:
			button.pressed.connect(_on_chat_button_pressed)
		elif sub_location_label == REST_LABEL:
			button.pressed.connect(_on_rest_button_pressed)
		sub_locations_container.add_child(button)


func _find_entered_map_object() -> MapObjectData:
	for obj in MapObjectData.get_all():
		if obj.id == MapSessionStore.entered_map_object_id:
			return obj
	return null


## 城堡守衛擋門 → 戰鬥 → 依勝負反應,整段流程(對話文案/AskBattle 詢問/戰報回傳)
## 全部交給 System/event/castle/castle_gate_event.gd 的 CastleGateEvent 接管,這裡只
## 負責告訴它事件結束後要回哪個場景(這個地點選單本身)。
func _on_castle_button_pressed() -> void:
	CastleGateEvent.trigger("res://Scenes/MapLocation/map_location.tscn")


## 隨機村民聊天,同樣整段交給 System/event/castle/castle_chat_event.gd 的
## CastleChatEvent 接管,聊完回到這個地點選單本身。
func _on_chat_button_pressed() -> void:
	CastleChatEvent.trigger("res://Scenes/MapLocation/map_location.tscn")


func _on_leave_button_pressed() -> void:
	var error := get_tree().change_scene_to_file("res://Scenes/Map/Map.tscn")
	if error != OK:
		printerr("Error changing scene to map: ", error)


## 休息:退回大地圖並直接開始播放時間(不用玩家手動按空白鍵),讓世界時間流逝
## 帶動 Character.advance_hp_regen() 自然回血(見 Scenes/Map/map.gd 的 _process())。跟
## 「離開」的差異只差在這裡強制把 MapSessionStore.is_playing 蓋成 true——
## map.gd 的 _ready() 本來就會讀這個欄位還原播放狀態,不需要另外開一個交接欄位。
func _on_rest_button_pressed() -> void:
	MapSessionStore.is_playing = true
	var error := get_tree().change_scene_to_file("res://Scenes/Map/Map.tscn")
	if error != OK:
		printerr("Error changing scene to map: ", error)
