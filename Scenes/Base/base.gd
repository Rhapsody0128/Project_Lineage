extends Node2D

## 根據地場景整合層,比照 Scenes/Map/map.gd 的角色分工,但沒有走位/攝影機拖曳縮放
## (使用者已確認:直接點擊建築物,不做角色走到定點——見計畫)。背景圖 1024x559,
## 靠根節點 scale 撐滿視窗寬度,UI 放獨立 CanvasLayer 不受這個 scale 影響。跟大地圖
## 一樣掛 HeaderBar(見 Scripts/UI/header_bar.gd),資源下拉選單走
## HeaderBar.add_resource_menu_button()(Map 場景也掛同一顆,見 map.gd),不另外開一條
## 常駐的資源列。建築本身不畫任何額外圖層(不疊色塊、不顯示中文名稱標籤)——
## Images/Base/base.jpg 的美術已經畫好建築長相,BuildingLibrary 的 territory_polygon
## 只用來做點擊命中判定(見 BaseSystem.pick_building()),純資料、不需要對應的畫面節點。

@onready var action_panel: BaseActionPanel = $UI/ActionPanel
@onready var ui_layer: CanvasLayer = $UI

var _base_system := BaseSystem.new()
var _buildings: Array[Building] = []
var header_bar: HeaderBar


func _ready() -> void:
	_buildings = BuildingLibrary.get_all()

	header_bar = HeaderBar.new()
	ui_layer.add_child(header_bar)
	header_bar.add_resource_menu_button()


func _process(_delta: float) -> void:
	_update_hover_cursor()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var picked := _base_system.pick_building(get_local_mouse_position(), _buildings)
		if picked != null:
			action_panel.open_for_building(picked)


## 滑鼠懸停在可點擊的建築上時換成手指游標,跟 Scenes/Map/map.gd 的
## _update_hover_cursor() 同一套邏輯;離開場景要記得還原(見 _exit_tree()),否則其他
## 場景會沿用這裡設定的游標。
func _update_hover_cursor() -> void:
	var hovered := _base_system.pick_building(get_local_mouse_position(), _buildings)
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if hovered != null else Input.CURSOR_ARROW)


func _exit_tree() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


## 回到根據地的 MapLocation 選單頁(不是直接回大地圖),MapSessionStore.entered_map_object_id
## 還留著,map_location.gd._find_entered_map_object() 能正確還原成「根據地」那一頁。
func _on_leave_button_pressed() -> void:
	var error := get_tree().change_scene_to_file("res://Scenes/MapLocation/map_location.tscn")
	if error != OK:
		printerr("Error changing scene to map location: ", error)
