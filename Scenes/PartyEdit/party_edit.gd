extends Control

# =========================================================
# 小隊編成畫面,排版比照 Scenes/Battle/battle.tscn:純視覺的棋盤
# (GridBoard,跟 Battle 的 BoardCanvas 共用同一份 BoardTileRenderer)
# 疊「可否放置」層(AvailabilityLayer,反灰未解鎖格 + 拖曳合法性
# 高亮 + 拖曳來源/放置目標)疊已放置角色圖層(PlacedLayer),最上層
# 是 UI(TopBar 按鈕 + 右側候補角色清單,仿 Battle 的 LogPanel 版位)
# ——UI 整層 mouse_filter=IGNORE,只有裡面的按鈕/清單本身接收點擊,
# 這樣才不會被底下滿版的棋盤/可放置層擋掉輸入(比照 battle.tscn 的
# UI 節點寫法)。
#
# 角色卡片可拖到網格上依 battle_cost 形狀佔格,已放置的角色也可以
# 再拖動(含拖回右側清單取消放置)。拖曳中按 E/Q 旋轉形狀。所有佔用
# 規則/合法性判斷都轉呼叫 System 層的 PartyEditGrid,這裡只做畫面
# 呈現與輸入轉發。
# =========================================================

@onready var board: PartyEditBoard = $GridBoard
@onready var availability_layer: PartyEditAvailabilityLayer = $AvailabilityLayer
@onready var placed_layer: Control = $PlacedLayer
@onready var right_panel: PanelContainer = $UI/RightPanel
@onready var roster_scroll_container: ScrollContainer = $UI/RightPanel/Margin/VBox/ScrollContainer
@onready var roster_list: VBoxContainer = $UI/RightPanel/Margin/VBox/ScrollContainer/RosterList
@onready var sort_filter_bar: CharacterSortFilterBar = $UI/RightPanel/Margin/VBox/SortFilterBar
@onready var add_character_button: Button = $UI/TopBar/AddCharacterButton
@onready var grow_grid_button: Button = $UI/TopBar/GrowGridButton
@onready var start_battle_button: Button = $UI/TopBar/StartBattleButton
@onready var finish_edit_button: Button = $UI/TopBar/FinishEditButton
@onready var back_button: Button = $UI/TopBar/BackButton

## 編輯中的草稿,從 PartyStore 上次「完成編輯」的快照 clone() 出一份獨立
## 副本(沒有就新建一份空的);編輯過程只改這份草稿,按下「完成編輯」才會
## 把草稿寫回 PartyStore,見 PartyStore 開頭註解。
var grid: PartyEditGrid


func _ready() -> void:
	for button in [add_character_button, grow_grid_button, start_battle_button, finish_edit_button, back_button]:
		UiStyle.apply_wood_plaque_button(button, 16.0, 8.0)
		button.add_theme_font_size_override("font_size", 18)
	UiStyle.apply_parchment_panel(right_panel, 480.0, 780.0)
	UiStyle.apply_parchment_scrollbar(roster_scroll_container)

	grid = PartyStore.grid.clone() if PartyStore.grid != null else PartyEditGrid.new()
	availability_layer.grid = grid
	availability_layer.placement_changed.connect(_refresh_all)
	availability_layer.leader_change_requested.connect(_on_leader_change_requested)
	sort_filter_bar.changed.connect(_refresh_roster)
	_refresh_all()


## 右鍵點擊已放置角色 = 設為隊長(見 PartyEditAvailabilityLayer.leader_change_requested);
## 只影響已放置圖層的金色標記,不用重新整理候補清單。
func _on_leader_change_requested(character: Character) -> void:
	grid.set_leader(character)
	_refresh_placed_layer()
	_update_finish_button_state()


func _on_add_character_pressed() -> void:
	var character := CharacterController.get_random_character(GameEnums.RankType.F)
	AllCharacterStore.register(character)
	CharacterRosterStore.all_characteres.append(character)
	_refresh_roster()


func _on_grow_grid_pressed() -> void:
	grid.unlock_random_locked_cell()
	availability_layer.queue_redraw()


func _on_back_pressed() -> void:
	NavigationStore.go_back()


## 以現在編成開始戰鬥:把目前放置在網格上的角色組成 Party,連同每個角色在網格上的
## 站位(battle_cost_positions,座標系跟 Battle 自身區同一套,見 PartyEditGrid 開頭
## 註解)一起記錄下來,交給 BattleReportStore 帶去 Battle 場景,對上一個隨機敵方小隊
## (BattleController.get_battle_with_self_party())。Battle 開戰佈陣時(見 battle.gd
## 的 _deploy_side())會直接照這些站位站,不是預設的靠邊縱隊。沒放任何角色時不給按。
## 固定走即時戰鬥模式(逐回合跑,回合間可以手動施放奧義,見 Scenes/Battle/battle.gd 的
## _run_battle_realtime())——玩家自己編成上場,理所當然要能操作,不用另外分兩顆按鈕。
func _on_start_battle_pressed() -> void:
	var party := _build_party_from_grid()
	if party == null:
		return

	BattleReportStore.pending_self_party = party
	BattleReportStore.pending_battle_mode = GameEnums.BattleMode.REALTIME
	NavigationStore.go_to("res://Scenes/Battle/battle.tscn")


## 完成編輯:把目前草稿(grid)寫回 PartyStore(快照 + 轉換出的 Party),
## 供其他場景讀取。按鈕本身依 _update_finish_button_state() 在不符合「戰場上
## 至少一人」+「至少一人是隊長」時就 disabled,這裡不用重覆判斷。
## 不切場景,只在原地提示結果。
func _on_finish_edit_pressed() -> void:
	PartyStore.grid = grid.clone()
	PartyStore.save_party(_build_party_from_grid())


## 「完成編輯」是否可按:戰場上至少要有一人,且必須有一人是隊長。
## get_leader() 只要場上有人就一定會退回預設隊長(見 PartyEditGrid.get_leader()),
## 這裡仍明確檢查兩個條件,呼應需求的兩項各自獨立條件,不依賴實作細節。
func _update_finish_button_state() -> void:
	finish_edit_button.disabled = grid.get_all_placed_characteres().is_empty() or grid.get_leader() == null


func _build_party_from_grid() -> Party:
	var placed := grid.get_all_placed_characteres()
	if placed.is_empty():
		return null

	var characteres: Array[Character] = []
	for character in placed:
		characteres.append(character)

	var party := Party.new("玩家小隊", characteres, grid.get_leader())
	party.ultimates = UltimateLibrary.default_ultimates()
	for character in placed:
		party.set_battle_position(character, grid.get_placement_anchor(character))
	return party


func _refresh_all() -> void:
	_refresh_roster()
	_refresh_placed_layer()
	_update_finish_button_state()


func _refresh_roster() -> void:
	for child in roster_list.get_children():
		child.queue_free()
	var candidates: Array[Character] = []
	for character in CharacterRosterStore.all_characteres:
		if not grid.is_placed(character):
			candidates.append(character)
	for character in sort_filter_bar.filter.apply(candidates):
		roster_list.add_child(CharacterCard.new(character))


func _refresh_placed_layer() -> void:
	for child in placed_layer.get_children():
		child.queue_free()
	var leader := grid.get_leader()
	for character in grid.get_all_placed_characteres():
		var view := BattleCostView.new()
		view.cell_size = PartyEditBoard.TILE_SIZE
		view.weapon = character.weapon
		view.is_leader = character == leader
		view.battle_cost = BattleCost.new(grid.get_placement_shape(character))
		placed_layer.add_child(view)
		# 佔位格(view 內軸心)要精準對齊 anchor 格,view 本地原點卻是 bounding box
		# 角落,所以要用 bounds_min 換算擺放位置。
		view.position = board.grid_corner_to_pixel(grid.get_placement_anchor(character)) + Vector2(view.bounds_min) * PartyEditBoard.TILE_SIZE


## 拖出網格外(例如拖回右側清單)= 取消放置。只接受來自網格的拖曳
## (origin=="grid",代表正在移動一個已放置的角色)。
func _can_drop_data(_at_position: Vector2, data) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.get("type") == "battle_cost_placement" and data.get("origin") == "grid"


func _drop_data(_at_position: Vector2, data) -> void:
	grid.remove(data["character"])
	_refresh_all()


## 拖曳中按 E/Q 即時旋轉形狀。Viewport.gui_get_drag_data() 拿到的是
## _get_drag_data() 當初回傳的同一個 Dictionary(參照型別),所以這裡
## 修改 data["shape"] 後,GridBoard 後續每次 _can_drop_data() 都會自動吃到
## 旋轉後的新形狀。旋轉數學丟給 System 層的 BattleCost,這裡只做資料搬運
## 與畫面更新。
func _unhandled_key_input(event: InputEvent) -> void:
	if not get_viewport().gui_is_dragging():
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode != KEY_E and event.keycode != KEY_Q:
		return

	var data = get_viewport().gui_get_drag_data()
	if typeof(data) != TYPE_DICTIONARY or data.get("type") != "battle_cost_placement":
		return

	var shape: Array[Vector2i] = data["shape"]
	if event.keycode == KEY_E:
		data["shape"] = BattleCost.new(shape).rotate_cw().cells
	else:
		data["shape"] = BattleCost.new(shape).rotate_ccw().cells

	var preview: BattleCostView = data["preview"]
	preview.battle_cost = BattleCost.new(data["shape"])
	# 置中對齊游標由 BattleCostView._process() 每一幀自己算(見
	# build_centered_drag_preview()),旋轉後下一幀會自動用新的 size 重新置中,
	# 這裡不用再手動改 position。
	get_viewport().set_input_as_handled()
