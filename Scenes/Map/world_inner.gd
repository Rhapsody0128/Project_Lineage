extends Node2D

## 大地圖世界邏輯:實例化 MapObject、驅動 MapSystem 逐幀推進、處理相機縮放/拖曳與點擊
## 移動輸入、同步玩家頭像位置與朝向動畫。規則邏輯全部轉發給 System/map/ 底下的
## RefCounted 類別,這裡只做顯示與輸入轉呼叫。
##
## 這是獨立場景檔 Scenes/Map/world_inner.tscn 的根節點腳本,美術/企劃要調整 Town/
## Castle 位置、縮放看整張地圖,直接開這個檔案就是一般的 2D 場景編輯,不受任何
## SubViewport 尺寸限制。實際遊玩時這個場景被 instance 進 Scenes/Map/map.tscn 的
## WORLD_VIEWPORT(SubViewport,見 map.gd)底下,顯示在 HeaderBar 底下那塊範圍——但這
## 支腳本完全不用知道這件事:`get_viewport_rect().size`(這裡的「viewport」就是那個
## WORLD_VIEWPORT)天生就是扣掉 HeaderBar 後的實際可視大小,滑鼠世界座標也天生是這個
## SubViewport 自己的局部座標系,從 (0,0) 開始,不用因為 HeaderBar 而調整任何鏡頭夾制/
## 地圖物件座標/地形 mask 換算。世界時間的實際推進由 HeaderBar 負責(見
## Scripts/UI/header_bar.gd,HeaderBar 掛在外層 map.gd 殼上),這裡只在 is_playing 時
## 額外把 WorldTimeStore.play_speed_multiplier 套用在地圖移動速度上,讓走路跟時間流逝
## 維持同一套加速比例。

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

## 角色移動時鏡頭跟隨的追趕速度(每秒趕上剩餘距離的比例,越大跟得越緊、
## 越小越有「緩慢滑動」的滯後感)。
const CAMERA_FOLLOW_LERP_SPEED := 3.0

@onready var camera: Camera2D = $Camera
@onready var map_objects_layer: Node2D = $MapObjectsLayer
@onready var roaming_enemy_layer: Node2D = $RoamingEnemiesLayer
@onready var war_battle_layer: Node2D = $WarBattleLayer
@onready var destination_line: Line2D = $DestinationLine
@onready var player_avatar: AnimatedSprite2D = $PlayerAvatar

var map_system: MapSystem
var party: Party
var _objects: Array[MapObject] = []
var _dragging := false
var _mouse_down_pos := Vector2.ZERO
var _last_dir_name := "Down"
## 角色移動時鏡頭是否自動跟隨置中——玩家拖曳畫面或按 WASD 平移鏡頭後關閉,
## 直到下一次點地圖發出新的移動指令(_handle_click_to_move())才重新開啟
## (見 _process() 的跟隨邏輯與 _drag_camera()/_update_wasd_pan() 的關閉時機)。
var _camera_following := true

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

## WarBattle.battle_id -> WarBattleVisual,鏡射 _enemy_visuals,理由相同(戰場資料活在
## NationRelationStore,跨場景不釋放,顯示節點每次進地圖要重建)。
var _war_battle_visuals: Dictionary = {}
## 分別鏡射 _current_map_object/_traveling_to,WarBattle 靜止不動,玩家點擊後走過去、
## 抵達即觸發,走跟 MapObject 相同的到達判斷分支,不是 RoamingEnemy 的距離撞上判定。
var _current_war_battle: WarBattle = null
var _traveling_to_war_battle: WarBattle = null

## 城鎮血統國家 → world_inner.tscn 裡手動擺放的 Town 場景節點名稱,見
## _sync_map_object_positions()。
const TOWN_NODE_NAMES: Dictionary = {
	GameEnums.BloodlineNation.LION: "Town_Lion",
	GameEnums.BloodlineNation.BEAR: "Town_Bear",
	GameEnums.BloodlineNation.EAGLE: "Town_Eagle",
	GameEnums.BloodlineNation.DRAGON: "Town_Dragon",
	GameEnums.BloodlineNation.DEER: "Town_Deer",
	GameEnums.BloodlineNation.LEOPARD: "Town_Leopard",
}
## 玩家根據地(唯一一個,不分血統國家)在 world_inner.tscn 裡手動擺放的節點名稱,同上。
const BASE_NODE_NAME := "Base"
## 城堡 MapObject.id → world_inner.tscn 裡手動擺放的 Castle 場景節點名稱,同上。城堡
## 同一地形有兩座、不像城鎮一個國家對一個節點,所以用 id(而非 nation)當 key。
const CASTLE_NODE_NAMES: Dictionary = {
	"PlainsCastle1": "Castle_Plains_1",
	"PlainsCastle2": "Castle_Plains_2",
	"MountainsCastle1": "Castle_Mountains_1",
	"MountainsCastle2": "Castle_Mountains_2",
	"PlateauCastle1": "Castle_Plateau_1",
	"PlateauCastle2": "Castle_Plateau_2",
	"ForestCastle1": "Castle_Forest_1",
	"ForestCastle2": "Castle_Forest_2",
	"DesertCastle1": "Castle_Desert_1",
	"DesertCastle2": "Castle_Desert_2",
	"IcefieldCastle1": "Castle_Icefield_1",
	"IcefieldCastle2": "Castle_Icefield_2",
}


func _ready() -> void:
	_objects = MapObject.get_all()
	_sync_map_object_positions()
	_spawn_map_objects()

	# 目前玩家 Party 從 PartyStore 取得;玩家尚未去過 PartyEdit 時該值為 null,
	# 為避免大地圖直接崩潰/卡死,fallback 用一組隨機小隊頂替(MVP 穩健性假設)。
	party = PartyStore.party
	if party == null:
		party = PartyController.get_random_party(GameEnums.RankType.F)

	var avg_agi := MapSystem.compute_average_agi(party)
	var speed := MapSystem.compute_speed(avg_agi)

	destination_line.visible = false
	# 城鎮/城堡是 world_inner.tscn 裡手動擺放、z_index 預設 0 的場景節點,這條線疊在
	# 移動路徑上一律要蓋在它們上面才看得清楚,所以給正值。
	destination_line.z_index = 1
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
			# 還原時優先接回原本剩下的折線(見 MapSessionStore.path_queue 註解),不能用
			# set_destination() 蓋掉——那會把還沒走完的路徑點清空,變成直接走直線衝向
			# 最後一個中繼點。
			var restored_path: Array[Vector2] = [MapSessionStore.target_position]
			restored_path.append_array(MapSessionStore.path_queue)
			map_system.set_path(restored_path)
			_traveling_to = _find_object_by_id(MapSessionStore.traveling_to_map_object_id)
			_current_map_object = null
		else:
			_current_map_object = _find_object_by_id(MapSessionStore.entered_map_object_id)
		camera.zoom = MapSessionStore.camera_zoom
		camera.position = MapSessionStore.camera_position
	else:
		# 出生點預設站在第一座城鎮(spec 未指定起始位置)。
		var start_pos := _objects[0].position if not _objects.is_empty() else MapSystem.MAP_SIZE / 2.0
		map_system = MapSystem.new(start_pos, speed)
		_current_map_object = _objects[0] if not _objects.is_empty() else null
		camera.zoom = ZOOM_MIN
		camera.position = start_pos

	player_avatar.position = map_system.position
	player_avatar.play("idle_Down")

	if MapSessionStore.rest_requested:
		MapSessionStore.rest_requested = false
		MapSessionStore.is_resting = true
		player_avatar.visible = false

	WorldTimeStore.day_passed.connect(_on_day_passed)

	_clamp_camera_position()
	if map_system.is_moving:
		_update_destination_line()

	# 遊蕩敵人資料活在 RoamingEnemyStore,離開/返回地圖不會被清空,但顯示節點
	# (RoamingEnemyVisual)每次都要重新掛——這裡先同步一次,不用等下一個 _process()。
	_sync_enemy_visuals()
	_sync_war_battle_visuals()

	if BaseLocationStore.is_relocating:
		ConfirmDialog.notify("請在地圖上點選新的根據地位置（Esc 取消）")


func _find_object_by_id(id: String) -> MapObject:
	for obj in _objects:
		if obj.id == id:
			return obj
	return null


func _find_object_by_type(type: int) -> MapObject:
	for obj in _objects:
		if obj.type == type:
			return obj
	return null


## 城鎮/城堡座標一律以 world_inner.tscn 裡手動擺放的節點為準(美術直接拖曳決定,見
## System/map/map_object.gd 的 get_all() 註解),這裡覆寫掉那邊存的快照數值,
## RoamingEnemySpawner 等獨立呼叫 MapObject.get_all() 的 System 層邏輯沒有場景樹可讀,
## 只能繼續吃那份快照,所以拖動節點後記得手動同步回 map_object.gd。
##
## 根據地(BASE)方向反過來:玩家可能已經遷移過(見 _apply_relocation()),但
## world_inner.tscn 場景檔本身不會記得這件事——每次重新載入這個場景,Base 節點都會回到
## .tscn 裡寫死的初始座標,不是玩家上次搬到的地方。所以 BASE 改成拿 BaseLocationStore
## (單一事實來源,見該檔案開頭註解)目前存的 position 覆寫回節點,而不是像城鎮/城堡那樣
## 讀節點目前位置存回資料——順序反了會讓每次重進大地圖都把遷移結果蓋回初始位置。
func _sync_map_object_positions() -> void:
	for obj in _objects:
		var node_name := _map_object_node_name(obj)
		if node_name.is_empty():
			continue
		var map_node := get_node_or_null(node_name)
		if map_node == null:
			continue
		if obj.type == GameEnums.MapObjectType.BASE:
			map_node.position = BaseLocationStore.position
			obj.position = BaseLocationStore.position
			# RoamingEnemyStore(autoload)全程持有同一個 spawner,它内部的根據地座標快照
			# 只在遊戲啟動當下拍過一次(見 RoamingEnemySpawner._map_objects),讀檔讀到
			# 已經遷移過的存檔時不會自動跟著換——這裡每次進大地圖都重新推一次,確保跟
			# BaseLocationStore 對得上,不用另外在讀檔流程特判。
			RoamingEnemyStore.spawner.update_base_position(BaseLocationStore.position)
			continue
		obj.position = map_node.position


func _map_object_node_name(obj: MapObject) -> String:
	if obj.type == GameEnums.MapObjectType.TOWN:
		return TOWN_NODE_NAMES.get(obj.nation, "")
	if obj.type == GameEnums.MapObjectType.BASE:
		return BASE_NODE_NAME
	if obj.type == GameEnums.MapObjectType.CASTLE:
		return CASTLE_NODE_NAMES.get(obj.id, "")
	return ""


## TOWN/BASE/CASTLE 物件的畫面就是 world_inner.tscn 裡那些手動擺放的節點本身(已經在
## 場景樹裡,一開始就看得到),不用再另外產生方塊/多邊形視覺;這裡只處理其他還沒有手動
## 擺放美術的物件(目前沒有,保留給之後新增的地點類型)。
func _spawn_map_objects() -> void:
	for obj in _objects:
		if not _map_object_node_name(obj).is_empty():
			continue
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
	# 每幀都同步一次目前座標/移動目標/相機進 MapSessionStore(見 _sync_session_state()
	# 註解)——不只是離開場景時才存一次,HeaderBar「存檔」在地圖上任何時刻按下都要能
	# 抓到當下最新位置,不能只靠 _exit_tree() 那一次性的收尾。
	_sync_session_state()

	# 世界時間的實際推進由 HeaderBar._process() 負責(見 Scripts/UI/header_bar.gd),
	# 這裡只管地圖移動。角色移動額外判斷 is_playing,跟世界時間共用同一個開關,兩者
	# 一起凍結/一起跑。倍速(WorldTimeStore.play_speed_multiplier,由 1/2/3/4 鍵或
	# HeaderBar 按鈕切換,4 是 DEMO 用的 100 倍速)套用在這裡的 delta 上,移動速度跟
	# 時間流逝維持同一套加速比例。
	if WorldTimeStore.controller.is_playing:
		# 士氣(MoraleStore)額外套用在移動速度上,跟世界時間倍速疊乘——高士氣走得快、
		# 低士氣走得慢,見 System/morale/morale_rule.gd 的 map_move_speed_multiplier()。
		var move_delta := delta * WorldTimeStore.play_speed_multiplier * (1.0 + MoraleRule.map_move_speed_multiplier(MoraleStore.value))

		if map_system.is_moving:
			# 追蹤中的敵人每幀都在自己遊蕩,目的地要跟著重新瞄準牠目前的位置,不能只在
			# 出發當下鎖死一個點——敵人走開後才不會撲空。敵人消失(戰鬥觸發/逃出可視
			# 範圍太遠被 despawn)就停止追蹤,維持在最後已知的位置前進。
			if _traveling_to_enemy != null:
				if RoamingEnemyStore.spawner.enemies.has(_traveling_to_enemy):
					map_system.target_position = _traveling_to_enemy.position
					# 每幀直接改瞄準點(不是重新規劃路徑),殘留的中繼路徑點會指向
					# 敵人舊位置,不清掉的話敵人到位後還要先繞去那些死點。
					map_system.path_queue.clear()
				else:
					_traveling_to_enemy = null

			# WarBattle 靜止不動,不需要像敵人那樣每幀重新瞄準,但它可能在玩家走過去的
			# 途中被月結算(NationRelationStore.settle_battle)從 active_battles 移除——
			# 這種情況要立刻停下來、丟失目標,不能讓玩家繼續走到定點觸發一個已經不存在的
			# 戰場事件(見 CLAUDE.md 已知待辦/使用者回報)。
			if _traveling_to_war_battle != null and not NationRelationStore.get_active_war_battles().has(_traveling_to_war_battle):
				map_system.is_moving = false
				destination_line.visible = false
				_traveling_to_war_battle = null
				WorldTimeStore.controller.is_playing = false
				MessageBar.show_message("戰場已經結束了。")
				return

			var prev_pos := map_system.position
			map_system.advance(move_delta)
			_update_player_visual(map_system.position - prev_pos, map_system.is_moving)
			player_avatar.position = map_system.position
			_update_destination_line()
			if _camera_following:
				camera.position = camera.position.lerp(map_system.position, clamp(CAMERA_FOLLOW_LERP_SPEED * delta, 0.0, 1.0))
				_clamp_camera_position()
			if not map_system.is_moving:
				destination_line.visible = false
				# 抵達目的地後一律自動觸發時間暫停,不論走去的是 MapObject 還是地圖
				# 空白處;只有走到 MapObject(_traveling_to 非 null)才記下「目前所在
				# 地點」並觸發進入流程——點空白處單純是移動過去,沒有對應地點可進。
				_current_map_object = _traveling_to
				_current_war_battle = _traveling_to_war_battle
				_traveling_to = null
				_traveling_to_enemy = null
				_traveling_to_war_battle = null
				WorldTimeStore.controller.is_playing = false
				if _current_map_object != null:
					_enter_map_object(_current_map_object)
					return
				if _current_war_battle != null:
					_enter_war_battle(_current_war_battle)
					return

		# 遊蕩敵人的生成/遊蕩/消失獨立於玩家是否正在走路(敵人可能自己晃進站著不動的
		# 玩家),所以放在 is_moving 判斷之外,只要世界時間在流動就推進。休息中跳過
		# 撞敵判定(見 MapSessionStore.is_resting 註解),敵人資料仍照常模擬,只是不會
		# 撞上玩家。
		_update_roaming_enemies(move_delta)
		_sync_war_battle_visuals()
		if not MapSessionStore.is_resting and _check_roaming_encounters():
			return
		# 旅行事件(見 System/event/map/travel/)只在玩家實際移動中才骰,不像遊蕩敵人連
		# 站著不動都可能被敵人晃過來撞上——沒有視覺實體可以主動避開,純粹是「走著走著
		# 遇到事」,所以額外限定 map_system.is_moving。
		if map_system.is_moving and not MapSessionStore.is_resting and _check_travel_events():
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


## 比對 NationRelationStore.get_active_war_battles() 與目前掛著的 WarBattleVisual 節點,
## 鏡射 _sync_enemy_visuals()。WarBattle 靜止不動、沒有可視範圍限制,不需要
## RoamingEnemySpawner.update() 那種逐幀生成/遊蕩邏輯,純粹是 diff,成本很低,直接每幀跑。
func _sync_war_battle_visuals() -> void:
	var live_ids: Dictionary = {}
	for battle in NationRelationStore.get_active_war_battles():
		live_ids[battle.battle_id] = true
		var visual: WarBattleVisual = _war_battle_visuals.get(battle.battle_id)
		if visual == null:
			visual = WarBattleVisual.new()
			war_battle_layer.add_child(visual)
			visual.setup(battle)
			_war_battle_visuals[battle.battle_id] = visual
		visual.update_visual()

	for id in _war_battle_visuals.keys():
		if not live_ids.has(id):
			_war_battle_visuals[id].queue_free()
			_war_battle_visuals.erase(id)


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


## TravelEventRoller(見 System/map/travel_event_roller.gd)骰到要觸發旅行事件時呼叫,
## 回傳 true 讓呼叫端跟 _check_roaming_encounters() 一樣同一幀不再繼續處理移動。停止移動/
## 時間比照撞上遊蕩敵人的既有作法,剩下的對話/效果全部交給 TravelEventLibrary 挑到的
## 事件物件自己接管。
func _check_travel_events() -> bool:
	if not TravelEventStore.roller.check(map_system.position):
		return false

	map_system.is_moving = false
	destination_line.visible = false
	_traveling_to = null
	_traveling_to_enemy = null
	WorldTimeStore.controller.is_playing = false

	TravelEventLibrary.trigger_random(map_system.position)
	return true


## 抵達地圖物件後的進入流程:切去泛用的地點選單場景——顯示哪個地點、有哪些子選項
## 全部由 map_object 這筆資料決定,這裡不寫死地點類型。相機不做任何調整,維持玩家
## 離開前的位置/縮放,由 _exit_tree() 統一存進 MapSessionStore 供回大地圖時還原。
func _enter_map_object(map_object: MapObject) -> void:
	var error := get_tree().change_scene_to_file("res://Scenes/MapLocation/map_location.tscn")
	if error != OK:
		printerr("Error changing scene to map location: ", error)


## 抵達 WarBattle 後的進入流程:WarBattleEvent 用 ActionPanel 疊加面板顯示,不切場景,
## 跟 _enter_map_object() 走場景轉換不同——戰場面板要讓玩家可以隨時關掉回到地圖繼續做
## 別的事,不是進一個獨立選單場景。
func _enter_war_battle(battle: WarBattle) -> void:
	WarBattleEvent.trigger(battle)


func _update_destination_line() -> void:
	var points := PackedVector2Array([map_system.position, map_system.target_position])
	for waypoint in map_system.path_queue:
		points.append(waypoint)
	destination_line.points = points
	destination_line.visible = true


## 滑鼠懸停在可點擊的 MapObject 上時換成手指游標,離開場景要記得還原
## (見 _exit_tree),否則其他場景會沿用這裡設定的游標。
func _update_hover_cursor() -> void:
	if _dragging:
		return
	var world_pos := camera.get_global_mouse_position()
	var hovered := map_system.pick_object(world_pos, _objects, PICK_RADIUS)
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if hovered != null else Input.CURSOR_ARROW)


## 離開 world_inner.tscn 前(不管是抵達地點、還是被 HeaderBar 選單切去其他場景)一律把
## 目前狀態存進 MapSessionStore,回來時才能還原座標/移動目標/相機(見
## Scripts/Autoload/map_session_store.gd)。世界時間/是否播放中不需要存——那是
## WorldTimeStore autoload 的狀態,離開/返回地圖不會重置它。
func _exit_tree() -> void:
	_sync_session_state()
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


## 跟 _exit_tree() 共用同一段狀態同步邏輯,額外由 _process() 每幀呼叫一次(見上方
## 說明)——存檔(Scripts/Autoload/save_load_store.gd)直接把 MapSessionStore 目前的
## 內容原封不動寫進存檔,不會另外去戳目前場景是不是地圖,靠這裡讓 MapSessionStore
## 本身隨時保持最新,存檔端不用關心呼叫時機。
func _sync_session_state() -> void:
	var entered_id := _current_map_object.id if _current_map_object != null else ""
	var traveling_id := _traveling_to.id if _traveling_to != null else ""
	MapSessionStore.save_map_state(
		map_system.position,
		map_system.target_position,
		map_system.path_queue,
		map_system.is_moving,
		camera.position,
		camera.zoom,
		entered_id,
		traveling_id
	)


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
	# 遷移根據地選點模式下按 Esc 直接取消,不套用任何變更——見 BaseLocationStore.
	# is_relocating 開頭註解。放在最前面,擋掉底下的拖曳/點擊判定。
	if BaseLocationStore.is_relocating and event.is_action_pressed("ui_cancel"):
		BaseLocationStore.is_relocating = false
		ConfirmDialog.notify("已取消遷移根據地")
		return
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
## 縮到最小(可視範圍 >= 地圖尺寸)時直接置中、不允許平移。`get_viewport_rect().size`
## 這裡指的是外層 WORLD_VIEWPORT(SubViewport,見 map.tscn)的實際大小——那個
## SubViewportContainer 開了 stretch=true,會自動把它同步成 HeaderBar 底下實際可視
## 大小,這裡量到的天生就是正確數字,不用另外處理 HeaderBar。
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
	_camera_following = false
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
	_camera_following = false
	camera.position += dir.normalized() * WASD_PAN_SPEED * camera.zoom * delta
	_clamp_camera_position()


func _handle_click_to_move() -> void:
	var world_pos := camera.get_global_mouse_position()

	# 遷移根據地選點模式下,點擊一律解讀成「挑選新根據地座標」,不觸發任何移動/進入地點
	# /追敵人邏輯(見 BaseLocationStore.is_relocating 開頭註解)。
	if BaseLocationStore.is_relocating:
		_handle_relocation_click(world_pos)
		return

	# 遊蕩敵人優先判定:直接點在敵人身上要瞄準牠、追過去,不是走去玩家點下滑鼠當下
	# 敵人所在的那個死點——敵人會自己遊蕩,見 _process() 每幀重新瞄準 _traveling_to_enemy
	# 目前位置那段。只挑玩家看得見的敵人,跟 _sync_enemy_visuals() 的可視判定一致。
	var picked_enemy := _pick_visible_enemy(world_pos)
	if picked_enemy != null:
		# 玩家主動點這隻敵人,視為明確想再次交手——就算是剛選過「離開」的同一隻、
		# 玩家根本沒走遠,也要立刻解除重觸發保護,不然會變成一直追著牠移動卻永遠碰不到
		# 對話(見 RoamingEnemySpawner.clear_declined() 註解)。
		RoamingEnemyStore.spawner.clear_declined(picked_enemy)
		_end_resting()
		map_system.set_path(_plan_route(picked_enemy.position))
		destination_line.visible = true
		_traveling_to_enemy = picked_enemy
		_traveling_to = null
		_traveling_to_war_battle = null
		_current_map_object = null
		_current_war_battle = null
		_camera_following = true
		WorldTimeStore.controller.is_playing = true
		return

	# WarBattle 是靜止的地圖地標(不像遊蕩敵人會走動),點擊判定比照 MapObject——
	# 已站在同一個 WarBattle 上再點一次直接重新開面板,否則走過去、抵達後才觸發
	# (見 _process() 的到達分支/_enter_war_battle())。
	var picked_battle := _pick_war_battle(world_pos)
	if picked_battle != null:
		if picked_battle == _current_war_battle:
			WorldTimeStore.controller.is_playing = false
			_enter_war_battle(picked_battle)
			return
		_end_resting()
		map_system.set_path(_plan_route(picked_battle.position))
		destination_line.visible = true
		_traveling_to_war_battle = picked_battle
		_traveling_to = null
		_traveling_to_enemy = null
		_current_map_object = null
		_current_war_battle = null
		_camera_following = true
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
	_end_resting()
	var destination := picked.position if picked != null else _clamp_to_map(world_pos)
	map_system.set_path(_plan_route(destination))
	destination_line.visible = true
	_traveling_to = picked
	_traveling_to_enemy = null
	_traveling_to_war_battle = null
	_current_map_object = null
	_current_war_battle = null
	_camera_following = true
	WorldTimeStore.controller.is_playing = true


## 玩家主動點地圖移動視為「醒來」——恢復頭像顯示與撞遊蕩敵人判定,見
## MapSessionStore.is_resting 註解。長休倒數中提早醒來,額外把倍速還原成 1 倍、清掉
## 目標天數(見 MapSessionStore.long_rest_target_day 註解),跟天數到達的
## _on_day_passed() 共用同一段還原邏輯,不用各自重複寫一次。
func _end_resting() -> void:
	if not MapSessionStore.is_resting:
		return
	MapSessionStore.is_resting = false
	player_avatar.visible = true
	if MapSessionStore.long_rest_target_day >= 0:
		MapSessionStore.long_rest_target_day = -1
		WorldTimeStore.set_speed_level(1)


## 長休天數到達:比照抵達目的地的既有作法直接暫停時間,交還操作權給玩家,再借用
## _end_resting() 統一還原倍速/頭像/撞敵判定(見上方註解)。跨天推進(高倍速一次推進
## 好幾天)靠 WorldTimeController.advance() 逐天觸發 day_passed,不會跳過目標天數那一天,
## 見 System/time/world_time_controller.gd。
func _on_day_passed() -> void:
	if MapSessionStore.long_rest_target_day < 0:
		return
	if WorldTimeStore.controller.world_time.get_day_count() < MapSessionStore.long_rest_target_day:
		return
	WorldTimeStore.set_playing(false)
	_end_resting()
	MessageBar.show_message("長休結束")


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


## 找出滑鼠點在哪個 WarBattle 上,取 PICK_RADIUS 內離滑鼠最近的一個;沒點中回傳 null。
## WarBattle 是明確的地圖地標,不像遊蕩敵人有可視範圍限制。
func _pick_war_battle(world_pos: Vector2) -> WarBattle:
	var closest: WarBattle = null
	var closest_dist := PICK_RADIUS
	for battle in NationRelationStore.get_active_war_battles():
		var d := battle.position.distance_to(world_pos)
		if d <= closest_dist:
			closest_dist = d
			closest = battle
	return closest


## 點空白處移動時,目的地夾在地圖範圍內——縮到很小時可以點到地圖外的灰色
## 區域,不夾住的話角色會走出 MAP_SIZE 邊界。
func _clamp_to_map(world_pos: Vector2) -> Vector2:
	return Vector2(
		clamp(world_pos.x, 0.0, MapSystem.MAP_SIZE.x),
		clamp(world_pos.y, 0.0, MapSystem.MAP_SIZE.y)
	)


## 點擊移動的目的地路徑規劃:玩家目前若站在地圖色塊 mask(見 MapTerrainMask)判定可行走
## 的範圍內,改用 MapPathfinder 算一條繞開山岳鏤空/海面的折線,不再是單純一條可能穿越
## 障礙物的直線(見 MapPathfinder 檔頭註解)。只影響「本來就站在可行走範圍內」的玩家,
## 站在範圍外時(理論上不會發生)點哪裡都不受影響,直接走原始直線。MapPathfinder 找不到
## 路徑(起訖點分屬不連通區域,理論上不會發生)時退回舊版「直線 + 邊界夾住」的簡化行為。
## 追蹤中的敵人/WarBattle 目的地每幀重新瞄準時不會再過這關(見 _process()),但敵人本身
## 已經靠 RoamingEnemy.advance_wander() 卡在同一塊範圍內,追過去的目的地自然也一直落在
## 範圍內。
func _plan_route(destination: Vector2) -> Array[Vector2]:
	if not MapTerrainMask.is_walkable(map_system.position):
		return [destination]
	var path := MapPathfinder.find_path(map_system.position, destination)
	if not path.is_empty():
		return path
	return [MapTerrainMask.clamp_segment_to_walkable(map_system.position, destination)]


## 遷移根據地選點模式下的點擊處理:合法性判斷交給 System/base/base_relocation_rule.gd
## (不太靠近城鎮/落在可通行地形),不合法只跳訊息提示、不開確認彈窗;資材是否足夠也在
## 這裡先擋一次,避免玩家點過合法性判斷、看到確認彈窗上的花費之後,按下去才又跳資材不足
## ——跟資材有關的判斷應該在同一個時間點一次告訴玩家。都通過才跳 ConfirmDialog 顯示花費,
## 確認才真的呼叫 _apply_relocation() 套用。
func _handle_relocation_click(world_pos: Vector2) -> void:
	var reason := BaseRelocationRule.invalid_reason(world_pos)
	if not reason.is_empty():
		ConfirmDialog.notify(reason)
		return
	if not BaseResourceStore.can_afford(BaseRelocationRule.COST):
		ConfirmDialog.notify("資材不足,無法遷移根據地")
		return
	ConfirmDialog.ask(
		"是否將根據地遷移至此處？將花費 %s" % _format_relocation_cost(),
		func(): _apply_relocation(world_pos)
	)


func _format_relocation_cost() -> String:
	var parts: Array[String] = []
	for resource_type in BaseRelocationRule.COST:
		parts.append("%s x%d" % [GameEnums.resource_string_label(resource_type), BaseRelocationRule.COST[resource_type]])
	return "、".join(parts)


## 套用遷移:扣資材、把 Base 場景節點與 BaseLocationStore.position 一起改成新座標——
## 兩者缺一不可,否則下次進大地圖 _sync_map_object_positions() 會直接把
## BaseLocationStore 蓋回節點原本(還沒搬動的)座標,見該函式開頭註解。本次 session 內的
## _objects 快照跟 RoamingEnemySpawner 各自快取的根據地座標也一併同步,不用重新進場景
## 才生效(見 RoamingEnemySpawner.update_base_position() 開頭註解)。_current_map_object
## 清空是因為玩家的頭像實際上還站在原地,根據地已經搬去別處,不能再被判定成「已經站在
## 根據地上」。
func _apply_relocation(pos: Vector2) -> void:
	BaseResourceStore.spend(BaseRelocationRule.COST)

	var base_node := get_node_or_null(BASE_NODE_NAME)
	if base_node != null:
		base_node.position = pos
	BaseLocationStore.position = pos

	var base_object := _find_object_by_type(GameEnums.MapObjectType.BASE)
	if base_object != null:
		base_object.position = pos
	if _current_map_object == base_object:
		_current_map_object = null

	RoamingEnemyStore.spawner.update_base_position(pos)

	BaseLocationStore.is_relocating = false
	ConfirmDialog.notify("根據地已遷移")
