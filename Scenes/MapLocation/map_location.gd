extends Control

## 泛用的「地點選單」畫面:抵達大地圖上的某個 MapObjectData 後顯示,顯示哪個地點、
## 有哪些子選項完全由該地點的資料決定(見 System/Map/MapObjectData.gd 的
## get_sub_locations()),這裡不寫死任何特定地點類型(城堡/村莊/遺跡等)的語意。

## 目前接了真實行為的子地點按鈕文字(見 System/Map/MapObjectData.gd 的
## TYPE_SUB_LOCATIONS),其餘子地點還是空按鈕佔位。
const CASTLE_LABEL := "城堡"
const CHAT_LABEL := "聊天"

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
		sub_locations_container.add_child(button)


func _find_entered_map_object() -> MapObjectData:
	for obj in MapObjectData.get_all():
		if obj.id == MapSessionStore.entered_map_object_id:
			return obj
	return null


func _on_castle_button_pressed() -> void:
	# 守衛擋門的選擇題,選項本身決定播完去哪個場景(闖進去/離開),見
	# DialogueLibrary.build_castle_gate_challenge() 的註解。
	var dialogue := DialogueLibrary.build_castle_gate_challenge(
		"res://Scenes/Battle/battle.tscn",
		"res://Scenes/MapLocation/map_location.tscn"
	)
	DialogueStore.queue(dialogue, "res://Scenes/MapLocation/map_location.tscn")
	var error := get_tree().change_scene_to_file("res://Scenes/Dialogue/dialogue_box.tscn")
	if error != OK:
		printerr("Error changing scene to dialogue: ", error)


func _on_chat_button_pressed() -> void:
	# 聊完回到同一個地點選單——DialogueStore 是交接點,見該檔案註解。
	DialogueStore.queue(DialogueLibrary.build_random_npc_chat(), "res://Scenes/MapLocation/map_location.tscn")
	var error := get_tree().change_scene_to_file("res://Scenes/Dialogue/dialogue_box.tscn")
	if error != OK:
		printerr("Error changing scene to dialogue: ", error)


func _on_leave_button_pressed() -> void:
	var error := get_tree().change_scene_to_file("res://Scenes/Map/Map.tscn")
	if error != OK:
		printerr("Error changing scene to map: ", error)
