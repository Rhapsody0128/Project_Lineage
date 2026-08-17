extends Node2D

## 大地圖整合層:實例化 MapObject、驅動 MapSystem 逐幀推進、處理相機縮放/拖曳與點擊
## 移動輸入、同步玩家頭像位置與朝向動畫。規則邏輯全部轉發給 System/map/ 底下的
## RefCounted 類別,這裡只做顯示與輸入轉呼叫。世界時間的實際推進由 HeaderBar 負責
## (見 Scripts/UI/header_bar.gd),這裡只在 is_playing 時額外把 WorldTimeStore.
## play_speed_multiplier 套用在地圖移動速度上,讓走路跟時間流逝維持同一套加速比例。

const ZOOM_MAX := Vector2(3.0, 3.0)
const ZOOM_MIN := Vector2(0.3, 0.3)
const ZOOM_FACTOR_PER_NOTCH := 1.1
const DRAG_CLICK_THRESHOLD_PX := 8.0
const PICK_RADIUS := 120.0
const DASH_LENGTH_PX := 16
const DASH_GAP_PX := 12
const LINE_WIDTH := 8.0
## 玩家與遊蕩敵人距離小於這個值視為「撞上」,觸發 RoamingEnemyEvent(見
## System/event/map/roaming_enemy_event.gd)。
const ENCOUNTER_RADIUS := 30.0

## 拖曳靈敏度隨目前縮放比率內插:zoom 在 ZOOM_MIN(放到最大/看得最細)時用
## MIN 倍率(貼著游標的自然手感,不額外加速);zoom 在 ZOOM_MAX(縮到最小/看
## 全圖)時用 MAX 倍率(大幅加快,才能一次拖過大範圍)。
const DRAG_SENSITIVITY_MIN := 6.0
const DRAG_SENSITIVITY_MAX := 6.0

## WASD 平移鏡頭速度(world units/sec,再乘上 camera.zoom,縮到越小畫面涵蓋範圍
## 越大,平移也要等比加快,手感才會跟拖曳一致)。
const WASD_PAN_SPEED := 5000.0

@onready var camera: Camera2D = $Camera
@onready var map_objects_layer: Node2D = $MapObjectsLayer
@onready var roaming_enemy_layer: Node2D = $RoamingEnemiesLayer
@onready var destination_line: Line2D = $DestinationLine
@onready var player_avatar: AnimatedSprite2D = $PlayerAvatar
@onready var ui_layer: CanvasLayer = $UI

var header_bar: HeaderBar
var map_system: MapSystem
var party: Party
var _objects: Array[MapObject] = []
var _dragging := false
var _mouse_down_pos := Vector2.ZERO
var _last_dir_name := "Down"

## RoamingEnemy.id -> RoamingEnemyVisual。敵人資料本身活在 RoamingEnemyStore(autoload,
## 跨場景不釋放),這個節點字典只是「目前這次進地圖畫面上掛了哪些對應的顯示節點」,
## 每次重新進 map.tscn 都要重建(見 _ready() 收尾呼叫的 _sync_enemy_visuals())。
var _enemy_visuals: Dictionary = {}

## 角色目前「所在」的 MapObject(非 null 代表就站在那個地點上,不是路過);
## 出發後清空,抵達目的地後才會指向新的地點。用來判斷「已經在王城,再點王城」
## 這種不該觸發任何事的情況,以及地圖是否有多個地點正確之外的其他判斷。
var _current_map_object: MapObject = null
## 目前正前往的 MapObject,抵達時用來把它寫進 _current_map_object。
var _traveling_to: MapObject = null
## 玩家直接點選遊蕩敵人移動時,追蹤中的目標——敵人本身會自己遊蕩,每幀都要把
## map_system.target_position 重新指向牠目前的位置,不能只在出發當下瞄一次死點,
## 否則敵人走開後玩家會撲空(見 _process() 的追蹤同步)。跟 _traveling_to(MapObject)
## 互斥,同一時間只會有一個非 null。
var _traveling_to_enemy: RoamingEnemy = null


func _ready() -> void:
	header_bar = HeaderBar.new()
	ui_layer.add_child(header_bar)

	_objects = MapObject.get_all()
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
		# 當下的座標/移動目標/相機,不要重新從出生點開始,也不要弄丟正在進行中的
		# 移動(見 Scripts/Autoload/map_session_store.gd 與 _exit_tree())。世界時間/
		# 是否播放中不需要還原——WorldTimeStore 是應用程式全程存活的 autoload,
		# 離開/返回地圖不會重置它的狀態。
		map_system = MapSystem.new(MapSessionStore.player_position, speed)
		if MapSessionStore.is_moving:
			map_system.set_destination(MapSessionStore.target_position)
			_traveling_to = _find_object_by_id(MapSessionStore.traveling_to_map_object_id)
			_current_map_object = null
		else:
			_current_map_object = _find_object_by_id(MapSessionStore.entered_map_object_id)
		camera.zoom = MapSessionStore.camera_zoom
		camera.position = MapSessionStore.camera_position
	else:
		# 出生點預設站在第一座城堡(spec 未指定起始位置)。
		var start_pos := _objects[0].position if not _objects.is_empty() else MapSystem.MAP_SIZE / 2.0
		map_system = MapSystem.new(start_pos, speed)
		_current_map_object = _objects[0] if not _objects.is_empty() else null
		camera.zoom = ZOOM_MIN
		camera.position = start_pos

	player_avatar.position = map_system.position
	player_avatar.play("idle_Down")

	header_bar.add_status_button()

	_clamp_camera_position()
	if map_system.is_moving:
		_update_destination_line()

	# 遊蕩敵人資料活在 RoamingEnemyStore,離開/返回地圖不會被清空,但顯示節點
	# (RoamingEnemyVisual)每次都要重新掛——這裡先同步一次,不用等下一個 _process()。
	_sync_enemy_visuals()


func _find_object_by_id(id: String) -> MapObject:
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
	# 世界時間的實際推進由 HeaderBar._process() 負責(見 Scripts/UI/header_bar.gd),
	# 這裡只管地圖移動。角色移動額外判斷 is_playing,跟世界時間共用同一個開關,兩者
	# 一起凍結/一起跑。倍速(WorldTimeStore.play_speed_multiplier,由 1/2/3/4 鍵或
	# HeaderBar 按鈕切換,4 是 DEMO 用的 100 倍速)套用在這裡的 delta 上,移動速度跟
	# 時間流逝維持同一套加速比例。
	if WorldTimeStore.controller.is_playing:
		var move_delta := delta * WorldTimeStore.play_speed_multiplier

		if map_system.is_moving:
			# 追蹤中的敵人每幀都在自己遊蕩,目的地要跟著重新瞄準牠目前的位置,不能只在
			# 出發當下鎖死一個點——敵人走開後才不會撲空。敵人消失(戰鬥觸發/逃出可視
			# 範圍太遠被 despawn)就停止追蹤,維持在最後已知的位置前進。
			if _traveling_to_enemy != null:
				if RoamingEnemyStore.spawner.enemies.has(_traveling_to_enemy):
					map_system.target_position = _traveling_to_enemy.position
				else:
					_traveling_to_enemy = null

			var prev_pos := map_system.position
			map_system.advance(move_delta)
			_update_player_visual(map_system.position - prev_pos, map_system.is_moving)
			player_avatar.position = map_system.position
			_update_destination_line()
			if not map_system.is_moving:
				destination_line.visible = false
				# 抵達目的地後一律自動觸發時間暫停,不論走去的是 MapObject 還是地圖
				# 空白處;只有走到 MapObject(_traveling_to 非 null)才記下「目前所在
				# 地點」並觸發進入流程——點空白處單純是移動過去,沒有對應地點可進。
				_current_map_object = _traveling_to
				_traveling_to = null
				_traveling_to_enemy = null
				WorldTimeStore.controller.is_playing = false
				if _current_map_object != null:
					_enter_map_object(_current_map_object)
					return

		# 遊蕩敵人的生成/遊蕩/消失獨立於玩家是否正在走路(敵人可能自己晃進站著不動的
		# 玩家),所以放在 is_moving 判斷之外,只要世界時間在流動就推進。
		_update_roaming_enemies(move_delta)
		if _check_roaming_encounters():
			return

	_update_wasd_pan(delta)
	_update_hover_cursor()


## 推進 RoamingEnemyStore 的生成/遊蕩/消失規則,再把畫面節點同步成目前的敵人清單。
func _update_roaming_enemies(move_delta: float) -> void:
	RoamingEnemyStore.spawner.update(map_system.position, move_delta)
	_sync_enemy_visuals()


## 比對 RoamingEnemyStore.spawner.enemies 與目前掛著的 RoamingEnemyVisual 節點:
## 新出現的敵人生一個 visual,消失的敵人(超出 DESPAWN_RADIUS 或被戰鬥事件消耗掉)
## 釋放對應 visual,其餘的同步位置/動畫,並依 VISION_RADIUS(隱藏可視範圍)決定
## 是否顯示——敵人資料本身在可視範圍外一樣存在/持續遊蕩,只是不畫出來,避免整張
## 地圖同時塞滿敵人。
func _sync_enemy_visuals() -> void:
	var live_ids: Dictionary = {}
	for enemy in RoamingEnemyStore.spawner.enemies:
		live_ids[enemy.id] = true
		var visual: RoamingEnemyVisual = _enemy_visuals.get(enemy.id)
		if visual == null:
			visual = RoamingEnemyVisual.new()
			roaming_enemy_layer.add_child(visual)
			visual.setup(enemy)
			_enemy_visuals[enemy.id] = visual
		visual.update_visual()
		visual.visible = RoamingEnemyStore.spawner.is_visible_to_player(enemy, map_system.position)

	for id in _enemy_visuals.keys():
		if not live_ids.has(id):
			_enemy_visuals[id].queue_free()
			_enemy_visuals.erase(id)


## 玩家(或遊蕩敵人自己晃過來)與看得見的敵人距離小於 ENCOUNTER_RADIUS 時觸發
## RoamingEnemyEvent,回傳是否有觸發(有的話呼叫端要 return,跟抵達 MapObject 的既有
## 收尾動作一樣不要在同一幀繼續處理移動)。只檢查看得見的敵人——可視範圍外的不算撞上。
## 剛被玩家選「離開」放過的敵人靠 should_skip_encounter() 暫時跳過,避免同一幀/下一幀
## 立刻又重新觸發同一場對話。
func _check_roaming_encounters() -> bool:
	for enemy in RoamingEnemyStore.spawner.enemies:
		if not RoamingEnemyStore.spawner.is_visible_to_player(enemy, map_system.position):
			continue
		if RoamingEnemyStore.spawner.should_skip_encounter(enemy, map_system.position):
			continue
		if map_system.position.distance_to(enemy.position) <= ENCOUNTER_RADIUS:
			_trigger_roaming_encounter(enemy)
			return true
	return false


## 撞上敵人的收尾:停止移動/時間(比照抵達 MapObject 的既有作法),交給
## RoamingEnemyEvent 接管對話/戰鬥流程。這隻敵人要不要真的從 RoamingEnemyStore 消失
## 由那邊依玩家選「戰鬥」還是「離開」決定(見 RoamingEnemyEvent._build_challenge()),
## 這裡只負責先把顯示節點收掉,不代表資料本身也沒了。
func _trigger_roaming_encounter(enemy: RoamingEnemy) -> void:
	map_system.is_moving = false
	destination_line.visible = false
	_traveling_to = null
	_traveling_to_enemy = null
	WorldTimeStore.controller.is_playing = false

	var visual: RoamingEnemyVisual = _enemy_visuals.get(enemy.id)
	if visual != null:
		visual.queue_free()
		_enemy_visuals.erase(enemy.id)

	RoamingEnemyEvent.trigger(enemy)


## 抵達地圖物件後的進入流程:切去泛用的地點選單場景——顯示哪個地點、有哪些子選項
## 全部由 map_object 這筆資料決定,這裡不寫死地點類型。相機不做任何調整,維持玩家
## 離開前的位置/縮放,由 _exit_tree() 統一存進 MapSessionStore 供回大地圖時還原。
func _enter_map_object(map_object: MapObject) -> void:
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


## 離開 map.tscn 前(不管是抵達地點、還是被 HeaderBar 選單切去其他場景)一律把
## 目前狀態存進 MapSessionStore,回來時才能還原座標/移動目標/相機(見
## Scripts/Autoload/map_session_store.gd)。世界時間/是否播放中不需要存——那是
## WorldTimeStore autoload 的狀態,離開/返回地圖不會重置它。
func _exit_tree() -> void:
	var entered_id := _current_map_object.id if _current_map_object != null else ""
	var traveling_id := _traveling_to.id if _traveling_to != null else ""
	MapSessionStore.save_map_state(
		map_system.position,
		map_system.target_position,
		map_system.is_moving,
		camera.position,
		camera.zoom,
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


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
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


## 點 MapObject 觸發地點事件,點地圖空白處則單純移動過去(抵達後暫停時間,
## 但不進入任何地點選單,見 _process() 的抵達判斷)。
## WASD 平移鏡頭,效果等同拖曳畫面——同樣直接套用位移,再交給
## _clamp_camera_position() 硬夾回地圖範圍內,不做慣性/加速。跟拖曳一樣不受
## is_playing 影響,時間暫停時也能看地圖。
func _update_wasd_pan(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		dir.y += 1.0
	if Input.is_key_pressed(KEY_A):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		dir.x += 1.0
	if dir == Vector2.ZERO:
		return
	camera.position += dir.normalized() * WASD_PAN_SPEED * camera.zoom * delta
	_clamp_camera_position()


func _handle_click_to_move() -> void:
	var world_pos := camera.get_global_mouse_position()

	# 遊蕩敵人優先判定:直接點在敵人身上要瞄準牠、追過去,不是走去玩家點下滑鼠當下
	# 敵人所在的那個死點——敵人會自己遊蕩,見 _process() 每幀重新瞄準 _traveling_to_enemy
	# 目前位置那段。只挑玩家看得見的敵人,跟 _sync_enemy_visuals() 的可視判定一致。
	var picked_enemy := _pick_visible_enemy(world_pos)
	if picked_enemy != null:
		# 玩家主動點這隻敵人,視為明確想再次交手——就算是剛選過「離開」的同一隻、
		# 玩家根本沒走遠,也要立刻解除重觸發保護,不然會變成一直追著牠移動卻永遠碰不到
		# 對話(見 RoamingEnemySpawner.clear_declined() 註解)。
		RoamingEnemyStore.spawner.clear_declined(picked_enemy)
		map_system.set_destination(picked_enemy.position)
		destination_line.visible = true
		_traveling_to_enemy = picked_enemy
		_traveling_to = null
		_current_map_object = null
		WorldTimeStore.controller.is_playing = true
		return

	var picked := map_system.pick_object(world_pos, _objects, PICK_RADIUS)
	if picked != null and picked == _current_map_object:
		# 已經站在這個地點,再點同一個 MapObject 不能走 set_destination()/is_playing=true
		# 那條路——之前正是這樣才會出現「已經在王城點王城,時間卻開始流逝」的 bug。
		# 觸發 MapObject 事件(打開地點選單)一律停止時間——「休息」會讓玩家站在
		# 原地播放中(見 Scenes/MapLocation/map_location.gd 的 _on_rest_button_pressed()),
		# 這裡若不主動關掉 is_playing,再點一次同一個地點會讓時間在玩家沒按空白鍵
		# 的情況下繼續偷跑。
		WorldTimeStore.controller.is_playing = false
		_enter_map_object(picked)
		return
	var destination := picked.position if picked != null else _clamp_to_map(world_pos)
	map_system.set_destination(destination)
	destination_line.visible = true
	_traveling_to = picked
	_traveling_to_enemy = null
	_current_map_object = null
	WorldTimeStore.controller.is_playing = true


## 找出滑鼠點在哪隻看得見的遊蕩敵人身上,取範圍內離滑鼠最近的一隻;沒點中回傳 null。
## 比照 MapSystem.pick_object() 對 MapObject 的做法,但敵人是動態清單、沒有多邊形領土,
## 純粹用 PICK_RADIUS 內最近點判定。
func _pick_visible_enemy(world_pos: Vector2) -> RoamingEnemy:
	var closest: RoamingEnemy = null
	var closest_dist := PICK_RADIUS
	for enemy in RoamingEnemyStore.spawner.enemies:
		if not RoamingEnemyStore.spawner.is_visible_to_player(enemy, map_system.position):
			continue
		var d := enemy.position.distance_to(world_pos)
		if d <= closest_dist:
			closest_dist = d
			closest = enemy
	return closest


## 點空白處移動時,目的地夾在地圖範圍內——縮到很小時可以點到地圖外的灰色
## 區域,不夾住的話角色會走出 MAP_SIZE 邊界。
func _clamp_to_map(world_pos: Vector2) -> Vector2:
	return Vector2(
		clamp(world_pos.x, 0.0, MapSystem.MAP_SIZE.x),
		clamp(world_pos.y, 0.0, MapSystem.MAP_SIZE.y)
	)
