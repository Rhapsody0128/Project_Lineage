extends Node2D

## 根據地場景整合層,比照 Scenes/Map/map.gd 的角色分工,但沒有走位/攝影機拖曳縮放
## (使用者已確認:直接點擊建築物,不做角色走到定點——見計畫)。背景圖原始尺寸
## 1024x559,靠根節點 scale 的 x/y 分別撐滿「實際執行時的視窗大小」,讓背景滿版鋪滿
## 畫面(比照 Dialogue 場景背景用 anchor 滿版的效果)。不能像先前那樣把 scale 寫死在
## .tscn(算的是 project.godot 設計時的 1920x1080),因為 HTML5 匯出在瀏覽器裡視窗比例
## 不保證等於設計比例(例如 1920x980)——`window/stretch/aspect="keep_height"` 只保證
## 邏輯高度貼齊,寬度會依實際視窗比例變動,寫死寬度會在較寬的視窗右側留空白。改成
## `_fit_background_to_viewport()` 在 `_ready()` 用 `get_viewport_rect().size` 即時算,
## 並接 `get_viewport().size_changed` 在瀏覽器視窗被使用者拖曳縮放時重算(場景節點釋放時
## Node 訊號會自動斷線,不需手動 disconnect)。非等比縮放造成的些微變形可接受,因為
## Images/Base/base.jpg 上沒有疊其他需要維持長寬比的圖層。BaseSystem.pick_building() 用
## Building.territory_polygon(使用者在原圖 1024x559 像素座標點出來的多邊形)比對
## get_local_mouse_position(),因為 Node2D.scale 就是 Godot 內建座標轉換,不管當下算出來
## 的 x/y 縮放比例是多少,click 判定一樣正確,不需要額外換算。UI 放獨立 CanvasLayer 不受
## 這個 scale 影響。跟大地圖
## 一樣掛 HeaderBar(見 Scripts/UI/header_bar.gd),隊伍/資源狀態面板走
## HeaderBar.add_status_button()(Map 場景也掛同一顆,見 map.gd),不另外開一條
## 常駐的資源列。建築本身不畫任何額外圖層(不疊色塊、不顯示中文名稱標籤)——
## Images/Base/base.jpg 的美術已經畫好建築長相,BuildingLibrary 的 territory_polygon
## 只用來做點擊命中判定(見 BaseSystem.pick_building()),純資料、不需要對應的畫面節點。

@onready var ui_layer: CanvasLayer = $UI
@onready var leave_button: Button = $UI/LeaveButton
@onready var background: TextureRect = $Background

var _base_system := BaseSystem.new()
var _buildings: Array[Building] = []
var header_bar: HeaderBar


func _ready() -> void:
	_buildings = BuildingLibrary.get_all()

	_fit_background_to_viewport()
	get_viewport().size_changed.connect(_fit_background_to_viewport)

	header_bar = HeaderBar.new()
	ui_layer.add_child(header_bar)
	header_bar.add_status_button()

	UiStyle.apply_wood_plaque_button(leave_button, 24.0, 12.0)
	leave_button.add_theme_font_size_override("font_size", 22)


## 用背景貼圖的原始像素尺寸對「當下實際」的視窗大小算出 x/y 縮放比例,取代寫死的
## scale 數值,見上方檔案開頭註解為什麼不能寫死。
func _fit_background_to_viewport() -> void:
	var texture_size := background.texture.get_size()
	var viewport_size := get_viewport_rect().size
	scale = viewport_size / texture_size


func _process(_delta: float) -> void:
	_update_hover_cursor()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var picked := _base_system.pick_building(get_local_mouse_position(), _buildings)
		if picked != null:
			BaseBuildingEvent.trigger(picked)


## 滑鼠懸停在可點擊的建築上時換成手指游標,跟 Scenes/Map/map.gd 的
## _update_hover_cursor() 同一套邏輯;離開場景要記得還原(見 _exit_tree()),否則其他
## 場景會沿用這裡設定的游標。
func _update_hover_cursor() -> void:
	var hovered := _base_system.pick_building(get_local_mouse_position(), _buildings)
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if hovered != null else Input.CURSOR_ARROW)


func _exit_tree() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


## 回到根據地的 MapLocation 選單頁(不是直接回大地圖),交給 BaseLeaveEvent 先播一句
## castle_interior.png 收尾過場——MapSessionStore.entered_map_object_id 還留著,
## map_location.gd._find_entered_map_object() 能正確還原成「根據地」那一頁。
func _on_leave_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/MapLocation/map_location.tscn")
