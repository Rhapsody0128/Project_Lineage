extends Node2D

## 大地圖整合層:實例化 MapObject、驅動 MapSystem/WorldTime 逐幀推進、
## 處理相機縮放/拖曳與點擊移動輸入、同步玩家頭像位置與朝向動畫。
## 規則邏輯全部轉發給 System/Map/ 底下的 RefCounted 類別,這裡只做顯示與輸入轉呼叫。

const ZOOM_MAX := Vector2(3.0, 3.0)
const ZOOM_MIN := Vector2(0.3, 0.3)
const ZOOM_FACTOR_PER_NOTCH := 1.1
const DRAG_CLICK_THRESHOLD_PX := 8.0
const PICK_RADIUS := 120.0
const DASH_LENGTH_PX := 16
const DASH_GAP_PX := 12
const LINE_WIDTH := 8.0

## 拖曳靈敏度隨目前縮放比率內插:zoom 在 ZOOM_MIN(放到最大/看得最細)時用
## MIN 倍率(貼著游標的自然手感,不額外加速);zoom 在 ZOOM_MAX(縮到最小/看
## 全圖)時用 MAX 倍率(大幅加快,才能一次拖過大範圍)。
const DRAG_SENSITIVITY_MIN := 6.0
const DRAG_SENSITIVITY_MAX := 6.0

@onready var camera: Camera2D = $Camera
@onready var map_objects_layer: Node2D = $MapObjectsLayer
@onready var destination_line: Line2D = $DestinationLine
@onready var player_avatar: AnimatedSprite2D = $PlayerAvatar
@onready var ui_layer: CanvasLayer = $UI

var header_bar: HeaderBar
var map_system: MapSystem
var world_time: WorldTime
## 玩家小隊,離開 _ready() 後仍要留著給 _process() 的 HP 回血用(見 Hero.advance_hp_regen())。
var party: Party
var _objects: Array[MapObjectData] = []
var _dragging := false
var _mouse_down_pos := Vector2.ZERO
var _last_dir_name := "Down"
var _is_playing := false

## 角色目前「所在」的 MapObject(非 null 代表就站在那個地點上,不是路過);
## 出發後清空,抵達目的地後才會指向新的地點。用來判斷「已經在王城,再點王城」
## 這種不該觸發任何事的情況,以及地圖是否有多個地點正確之外的其他判斷。
var _current_map_object: MapObjectData = null
## 目前正前往的 MapObject,抵達時用來把它寫進 _current_map_object。
var _traveling_to: MapObjectData = null


func _ready() -> void:
	header_bar = HeaderBar.new()
	ui_layer.add_child(header_bar)

	_objects = MapObjectData.get_all()
	_spawn_map_objects()

	# 目前玩家 Party 從 PartyStore 取得;玩家尚未去過 PartyEdit 時該值為 null,
	# 為避免大地圖直接崩潰/卡死,fallback 用一組隨機小隊頂替(MVP 穩健性假設)。
	party = PartyStore.party
	if party == null:
		party = PartyController.get_random_party()

	var avg_agi := MapSystem.compute_average_agi(party)
	var speed := MapSystem.compute_speed(avg_agi)

	destination_line.visible = false
	destination_line.width = LINE_WIDTH
	destination_line.texture = _create_dash_texture()
	destination_line.texture_mode = Line2D.LINE_TEXTURE_TILE
	# LINE_TEXTURE_TILE 要靠這個才會真的沿線重複貼圖——texture_repeat 預設是
	# disabled,UV 超過 [0,1] 會直接夾在材質最後一欄(剛好是透明的 gap 那端),
	# 導致線只有貼近起點的一小段(材質寬度 28 世界單位)看得到,後面全部透明。
	destination_line.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

	if MapSessionStore.has_saved_state:
		# 從其他場景(地點選單、HeaderBar 選單切去的戰報/隊伍編輯等)返回:還原離開
		# 當下的座標/移動目標/世界時間/相機,不要重新從出生點/B.C.621 年開始,也不要
		# 弄丟正在進行中的移動(見 Scripts/Autoload/map_session_store.gd 與 _exit_tree())。
		map_system = MapSystem.new(MapSessionStore.player_position, speed)
		if MapSessionStore.is_moving:
			map_system.set_destination(MapSessionStore.target_position)
			_traveling_to = _find_object_by_id(MapSessionStore.traveling_to_map_object_id)
			_current_map_object = null
		else:
			_current_map_object = _find_object_by_id(MapSessionStore.entered_map_object_id)
		world_time = WorldTime.new(1.0, MapSessionStore.day_accumulator)
		_is_playing = MapSessionStore.is_playing
		camera.zoom = MapSessionStore.camera_zoom
		camera.position = MapSessionStore.camera_position
	else:
		# 出生點預設站在第一座城堡(spec 未指定起始位置)。
		var start_pos := _objects[0].position if not _objects.is_empty() else MapSystem.MAP_SIZE / 2.0
		map_system = MapSystem.new(start_pos, speed)
		world_time = WorldTime.new()
		_current_map_object = _objects[0] if not _objects.is_empty() else null
		camera.zoom = ZOOM_MIN
		camera.position = start_pos

	player_avatar.position = map_system.position
	player_avatar.play("idle_Down")

	_clamp_camera_position()
	_update_date_label()
	if map_system.is_moving:
		_update_destination_line()


## 世界時間每往前推進一點,小隊全員跟著自然回血一點(見 Hero.advance_hp_regen()),
## 不限定要站在城堡/待在原地——大地圖上移動中也一樣回血。
func _regen_party_hp(days_elapsed: float) -> void:
	if party == null:
		return
	for hero in party.heroes:
		hero.advance_hp_regen(days_elapsed)


func _find_object_by_id(id: String) -> MapObjectData:
	for obj in _objects:
		if obj.id == id:
			return obj
	return null


func _spawn_map_objects() -> void:
	for obj in _objects:
		var visual := MapObjectVisual.new()
		map_objects_layer.add_child(visual)
		visual.setup(obj)


func _create_dash_texture() -> ImageTexture:
	var width := DASH_LENGTH_PX + DASH_GAP_PX
	var image := Image.create(width, 4, false, Image.FORMAT_RGBA8)
	for x in range(width):
		var color := Color(1, 1, 1, 1) if x < DASH_LENGTH_PX else Color(1, 1, 1, 0)
		for y in range(4):
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)


func _process(delta: float) -> void:
	# 暫停時世界時間與角色移動一起凍結;播放中則兩者一起跑(世界時間仍然
	# 不因「角色本身有沒有在動」而單獨停,只受播放/暫停這個開關控制)。
	if _is_playing:
		world_time.advance(delta)
		_regen_party_hp(delta * world_time.days_per_real_second)

		if map_system.is_moving:
			var prev_pos := map_system.position
			map_system.advance(delta)
			_update_player_visual(map_system.position - prev_pos, map_system.is_moving)
			player_avatar.position = map_system.position
			_update_destination_line()
			if not map_system.is_moving:
				destination_line.visible = false
				# 抵達地圖 OBJECT 後自動觸發時間暫停,同時記下「目前所在地點」。
				_current_map_object = _traveling_to
				_traveling_to = null
				_is_playing = false
				_enter_map_object(_current_map_object)
				return

	_update_date_label()
	_update_hover_cursor()


## 抵達地圖物件後的進入流程:切去泛用的地點選單場景——顯示哪個地點、有哪些子選項
## 全部由 map_object 這筆資料決定,這裡不寫死地點類型。相機不做任何調整,維持玩家
## 離開前的位置/縮放,由 _exit_tree() 統一存進 MapSessionStore 供回大地圖時還原。
func _enter_map_object(map_object: MapObjectData) -> void:
	var error := get_tree().change_scene_to_file("res://Scenes/MapLocation/map_location.tscn")
	if error != OK:
		printerr("Error changing scene to map location: ", error)


func _update_destination_line() -> void:
	destination_line.points = PackedVector2Array([map_system.position, map_system.target_position])
	destination_line.visible = true


## 滑鼠懸停在可點擊的 MapObject 上時換成手指游標,離開場景要記得還原
## (見 _exit_tree),否則其他場景會沿用這裡設定的游標。
func _update_hover_cursor() -> void:
	if _dragging:
		return
	var world_pos := camera.get_global_mouse_position()
	var hovered := map_system.pick_object(world_pos, _objects, PICK_RADIUS)
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if hovered != null else Input.CURSOR_ARROW)


## 離開 Map.tscn 前(不管是抵達地點、還是被 HeaderBar 選單切去其他場景)一律把
## 目前狀態存進 MapSessionStore,回來時才能還原座標/移動目標/世界時間/相機
## (見 Scripts/Autoload/map_session_store.gd)。
func _exit_tree() -> void:
	var entered_id := _current_map_object.id if _current_map_object != null else ""
	var traveling_id := _traveling_to.id if _traveling_to != null else ""
	MapSessionStore.save_map_state(
		map_system.position,
		map_system.target_position,
		map_system.is_moving,
		world_time.get_day_accumulator(),
		camera.position,
		camera.zoom,
		_is_playing,
		entered_id,
		traveling_id
	)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _update_player_visual(move_delta: Vector2, moving: bool) -> void:
	if not moving:
		player_avatar.play("idle_%s" % _last_dir_name)
		return
	if move_delta.length() < 0.001:
		return
	var dir_name := _dir_name(move_delta)
	_last_dir_name = dir_name
	player_avatar.play("walk_%s" % dir_name)


## 朝向優先序沿用 Scenes/Battle/battle_unit_visual.gd 的既有慣例:x 軸優先於 y 軸,
## 動畫名稱是 "Top" 不是 "Up"。
func _dir_name(dir: Vector2) -> String:
	if dir.x > 0:
		return "Right"
	elif dir.x < 0:
		return "Left"
	elif dir.y > 0:
		return "Down"
	elif dir.y < 0:
		return "Top"
	return "Down"


func _update_date_label() -> void:
	var state_text := "播放中" if _is_playing else "已暫停"
	header_bar.set_time_text("%s　%s" % [world_time.get_display_string(), state_text])


func _toggle_playing() -> void:
	_is_playing = not _is_playing


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_SPACE:
			_toggle_playing()
	elif event is InputEventMouseButton:
		var button_event := event as InputEventMouseButton
		if button_event.pressed and button_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_camera(false)
		elif button_event.pressed and button_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_camera(true)
		elif button_event.button_index == MOUSE_BUTTON_LEFT:
			if button_event.pressed:
				_dragging = false
				_mouse_down_pos = button_event.position
			else:
				var moved: float = button_event.position.distance_to(_mouse_down_pos)
				if moved <= DRAG_CLICK_THRESHOLD_PX:
					_handle_click_to_move()
				_dragging = false
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var motion_event := event as InputEventMouseMotion
		var moved: float = motion_event.position.distance_to(_mouse_down_pos)
		if moved > DRAG_CLICK_THRESHOLD_PX or _dragging:
			_dragging = true
			_drag_camera(motion_event.relative)


## 縮放以滑鼠位置為中心:縮放前先記下滑鼠目前指到的世界座標,套用新 zoom
## 後,把相機位置補償回去,讓同一個世界座標縮放後仍然落在滑鼠底下(而不是
## 鏡頭中心)。夾在地圖邊界時(_clamp_camera_position)這個對齊會被打斷,
## 屬預期行為。
func _zoom_camera(zoom_in: bool) -> void:
	var factor := (1.0 / ZOOM_FACTOR_PER_NOTCH) if zoom_in else ZOOM_FACTOR_PER_NOTCH
	var new_zoom := camera.zoom * factor
	new_zoom.x = clamp(new_zoom.x, ZOOM_MIN.x, ZOOM_MAX.x)
	new_zoom.y = clamp(new_zoom.y, ZOOM_MIN.y, ZOOM_MAX.y)
	if new_zoom == camera.zoom:
		return

	var mouse_world_before := camera.get_global_mouse_position()
	camera.zoom = new_zoom
	var mouse_world_after := camera.get_global_mouse_position()
	camera.position += mouse_world_before - mouse_world_after

	_clamp_camera_position()


## 縮放後立即把相機夾回地圖範圍內(硬夾,非拖曳手勢,不需要漸進阻力)。
## 縮到最小(可視範圍 >= 地圖尺寸)時直接置中、不允許平移。
func _clamp_camera_position() -> void:
	var half := get_viewport_rect().size * camera.zoom / 2.0
	var pos := camera.position
	pos.x = _clamp_axis(pos.x, half.x, MapSystem.MAP_SIZE.x)
	pos.y = _clamp_axis(pos.y, half.y, MapSystem.MAP_SIZE.y)
	camera.position = pos


func _clamp_axis(value: float, half: float, map_size: float) -> float:
	if half * 2.0 >= map_size:
		return map_size / 2.0
	return clamp(value, half, map_size - half)


## 目前縮放比率對應的拖曳靈敏度:縮到最小(camera.zoom 接近 ZOOM_MAX)時
## 拖曳幅度大,放到最大(camera.zoom 接近 ZOOM_MIN)時貼近自然的游標手感。
func _current_drag_sensitivity() -> float:
	var t := inverse_lerp(ZOOM_MIN.x, ZOOM_MAX.x, camera.zoom.x)
	return lerp(DRAG_SENSITIVITY_MIN, DRAG_SENSITIVITY_MAX, clamp(t, 0.0, 1.0))


## 拖曳移動相機。不再做漸進阻力——直接套用位移,再交給 _clamp_camera_position()
## 硬夾回地圖範圍內,邊界行為單純是「碰到邊界就停」,不會有中間的減速地帶,
## 也就不會有阻力計算跟實際畫面邊緣對不上、導致還是看得到地圖外灰色的問題。
func _drag_camera(relative_px: Vector2) -> void:
	var raw_delta := -relative_px * camera.zoom * _current_drag_sensitivity()
	camera.position += raw_delta
	_clamp_camera_position()


func _handle_click_to_move() -> void:
	var world_pos := camera.get_global_mouse_position()
	var picked := map_system.pick_object(world_pos, _objects, PICK_RADIUS)
	if picked == null:
		return
	if picked == _current_map_object:
		# 已經站在這個地點,再點同一個 MapObject 不能走 set_destination()/_is_playing=true
		# 那條路——之前正是這樣才會出現「已經在王城點王城,時間卻開始流逝」的 bug。
		# 觸發 MapObject 事件(打開地點選單)一律停止時間——「休息」會讓玩家站在
		# 原地播放中(見 Scenes/MapLocation/map_location.gd 的 _on_rest_button_pressed()),
		# 這裡若不主動關掉 _is_playing,再點一次同一個地點會把播放中的狀態帶進
		# MapSessionStore,回大地圖後時間會在玩家沒按空白鍵的情況下繼續偷跑。
		_is_playing = false
		_enter_map_object(picked)
		return
	map_system.set_destination(picked.position)
	destination_line.visible = true
	_traveling_to = picked
	_current_map_object = null
	_is_playing = true
