extends Control

@onready var _map_button: Button = $CenterContainer/VBoxContainer/Map
@onready var _load_game_button: Button = $CenterContainer/VBoxContainer/LoadGame
@onready var _rhythm_button: Button = $CenterContainer/VBoxContainer/Rhythm
@onready var _quit_button: Button = $CenterContainer/VBoxContainer/Quit

func _ready() -> void:
	_ensure_starting_party()
	UiStyle.apply_wood_plaque_button(_map_button)
	UiStyle.apply_wood_plaque_button(_load_game_button)
	UiStyle.apply_wood_plaque_button(_rhythm_button)
	UiStyle.apply_wood_plaque_button(_quit_button)


## 遊戲一開始(PartyStore.party 還是 null,代表玩家沒去過 PartyEdit 編過隊)就
## 直接生成固定主角、加入 AllCharacterStore/CharacterRosterStore,同時把
## PartyEditGrid 也一起擺好(靠左置中,見 PartyEditGrid.find_leaning_left_anchor())
## 寫入 PartyStore.grid,再照這份擺盤組出 Party 寫入 PartyStore.party——玩家不用
## 先跑一趟 PartyEdit 才有隊伍可用,之後打開 PartyEdit 畫面也會直接看到主角已經
## 站在靠左置中的位置,而不是空板子。玩家自己編輯過隊伍後 PartyStore.party 就不是
## null,不會被這裡覆蓋。
func _ensure_starting_party() -> void:
	if PartyStore.party != null:
		return

	var protagonist := CharacterController.get_fixed_protagonist()
	CharacterRosterStore.try_add(protagonist)

	var grid := PartyEditGrid.new()
	var anchor := grid.find_leaning_left_anchor(protagonist.battle_cost.cells)
	var has_anchor := anchor != Vector2i(-1, -1)
	if has_anchor:
		grid.place(protagonist, protagonist.battle_cost.cells, anchor)
		grid.set_leader(protagonist)
		PartyStore.grid = grid

	var characteres: Array[Character] = [protagonist]
	var party := Party.new("玩家小隊", characteres, protagonist)
	party.ultimates = UltimateLibrary.default_ultimates()
	party.set_battle_position(protagonist, anchor if has_anchor else Vector2i(1, 2))
	PartyStore.save_party(party)


func _on_map_pressed() -> void:
	var error := get_tree().change_scene_to_file("res://Scenes/Map/map.tscn")
	if error != OK:
		printerr("Error changing scene to map: ", error)


func _on_load_game_pressed() -> void:
	SaveSlotPicker.open_load_menu()


## 節奏小遊戲玩法測試用入口(見 Scenes/RhythmGame/），玩法定案、素材做好前先放主選單
## 方便直接開,之後嵌進根據地生產建築面板後這顆按鈕可以拿掉。
func _on_rhythm_pressed() -> void:
	var error := get_tree().change_scene_to_file("res://Scenes/RhythmGame/rhythm_game_test.tscn")
	if error != OK:
		printerr("Error changing scene to rhythm game test: ", error)


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_reports_pressed() -> void:
	NavigationStore.go_to("res://Scenes/BattleReportList/battle_report_list.tscn")
