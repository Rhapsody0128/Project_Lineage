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


func _on_castle_button_pressed() -> void:
	# 守衛擋門的選擇題,選項本身決定播完去哪個場景(闖進去/離開),見
	# DialogueLibrary.build_castle_gate_challenge() 的註解。玩家小隊抓 PartyStore.party
	# (玩家按過「完成編輯」的隊伍);還沒編過(null)就不生假隊伍頂著,直接由
	# build_castle_gate_challenge() 拿掉「闖進去」選項。選「闖進去」時才把這個小隊透過
	# BattleReportStore.pending_self_party 交給 Battle 場景(跟 PartyEdit「以現在編成開始
	# 戰鬥」同一套交接模式),不在選「離開」時髒寫,避免之後其他入口進 Battle 場景時
	# 誤用到這裡留下的殘值。玩家帶自己隊伍進的戰鬥一律走即時模式(pending_battle_mode
	# = REALTIME),才能在回合間手動施放奧義——跟點戰報播放(AUTO,單純重播不能操作)
	# 要分清楚,不要混用預設值。
	var self_party := PartyStore.party

	# 這趟會先繞去 Dialogue 場景,不是直接切去 Battle,所以「回上一頁」不能靠
	# NavigationStore.go_to() 在切場景當下自動抓 current_scene(那樣抓到的會是
	# Dialogue 自己)——在這裡先明講最終邏輯上的上一頁就是這個地點選單本身。
	NavigationStore.push_return_scene_path("res://Scenes/MapLocation/map_location.tscn")

	var dialogue := DialogueLibrary.build_castle_gate_challenge(
		"res://Scenes/Battle/battle.tscn",
		"res://Scenes/MapLocation/map_location.tscn",
		self_party,
		func():
			BattleReportStore.pending_self_party = self_party
			BattleReportStore.pending_battle_mode = GameEnums.BattleMode.REALTIME
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


## 休息:退回大地圖並直接開始播放時間(不用玩家手動按空白鍵),讓世界時間流逝
## 帶動 Hero.advance_hp_regen() 自然回血(見 Scenes/Map/map.gd 的 _process())。跟
## 「離開」的差異只差在這裡強制把 MapSessionStore.is_playing 蓋成 true——
## map.gd 的 _ready() 本來就會讀這個欄位還原播放狀態,不需要另外開一個交接欄位。
func _on_rest_button_pressed() -> void:
	MapSessionStore.is_playing = true
	var error := get_tree().change_scene_to_file("res://Scenes/Map/Map.tscn")
	if error != OK:
		printerr("Error changing scene to map: ", error)
