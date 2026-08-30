class_name PartyEditAvailabilityLayer
extends Control

# =========================================================
# PartyEdit 網格上「可否放置」的疊加層:反灰未解鎖的格子、拖曳中
# 的合法/不合法高亮,同時身兼拖曳來源(從已放置角色身上撿起來
# 移動)與放置目標。疊在共用的 PartyEditBoard(純視覺棋盤)之上、
# PlacedLayer(已放置角色圖示)之下。
#
# 佔用規則/合法性一律問 System 層的 PartyEditGrid,這裡只管畫面
# 與輸入轉發;放置已派駐根據地生產的角色需要先跳 ConfirmDialog 問玩家(見 _drop_data()),
# 這類「非佔用規則」的使用者提示留在這裡處理,不下放給 PartyEditGrid。
# =========================================================

signal placement_changed
## 右鍵點擊已放置角色時發出,呼叫端(party_edit.gd)接住後轉呼叫
## PartyEditGrid.set_leader()——設隊長的判斷/資料一律留在 System 層,
## 這裡只負責把輸入事件轉成「使用者想把誰設成隊長」的意圖。
signal leader_change_requested(character: Character)

const LOCKED_TINT := Color(0, 0, 0, 0.6)
const VALID_HIGHLIGHT := Color(0.4, 0.9, 0.4, 0.5)
const INVALID_HIGHLIGHT := Color(0.9, 0.3, 0.3, 0.5)

var grid: PartyEditGrid

var _hover_active := false
var _hover_anchor := Vector2i.ZERO
var _hover_shape: Array[Vector2i] = []
var _hover_valid := false

## 單純點一下已放置角色(按下到放開之間沒有觸發拖曳、也沒移到別格)= 取消放置,
## 不用特地拖出網格外才能取消——見 _gui_input()。_get_drag_data() 只有在放開前
## 滑鼠移動超過引擎內建的拖曳門檻才會真的開始拖曳,沒超過門檻的話按下/放開
## 一樣會照普通輸入事件送進 _gui_input(),藉此跟「這是一次點擊」的判斷區分開來。
var _click_press_active := false
var _click_press_cell := Vector2i.ZERO


func _draw() -> void:
	if grid == null:
		return

	for y in range(PartyEditGrid.GRID_ROWS):
		for x in range(PartyEditGrid.GRID_COLS):
			var cell := Vector2i(x, y)
			if not grid.is_unlocked(cell):
				var rect := Rect2(_corner_pixel(cell), Vector2(PartyEditBoard.TILE_SIZE, PartyEditBoard.TILE_SIZE))
				draw_rect(rect, LOCKED_TINT)

	if _hover_active:
		var color := VALID_HIGHLIGHT if _hover_valid else INVALID_HIGHLIGHT
		for offset in _hover_shape:
			var rect := Rect2(_corner_pixel(_hover_anchor + offset), Vector2(PartyEditBoard.TILE_SIZE, PartyEditBoard.TILE_SIZE))
			draw_rect(rect, color)


func _corner_pixel(cell: Vector2i) -> Vector2:
	return BoardTileRenderer.grid_corner_to_pixel(cell, PartyEditBoard.TILE_SIZE, PartyEditBoard.BOARD_ORIGIN)


func pixel_to_cell(local_pos: Vector2) -> Vector2i:
	var p := (local_pos - PartyEditBoard.BOARD_ORIGIN) / PartyEditBoard.TILE_SIZE
	return Vector2i(floori(p.x), floori(p.y))


## 形狀 bounding box 的實際像素大小,用來把游標對齊到「整體形狀」而不是佔位格
## ——佔位格(cells[0])只代表 BATTLE 站位用的軸心,不代表拖曳時的視覺重心。
func _shape_size_px(cost: BattleCost) -> Vector2:
	return Vector2(cost.bounds_max() - cost.bounds_min() + Vector2i.ONE) * PartyEditBoard.TILE_SIZE


## 游標位置換算成「這個形狀擺下去的話,佔位格會落在哪一格」——用整體 bounding box
## 置中對齊游標(跟 BattleCostView.build_centered_drag_preview() 的浮動預覽
## 用同一套「bounding box 中心對齊游標」算法,拖曳預覽跟實際落點/合法性高亮
## 才會完全一致),而不是直接把游標所在格當成佔位格。
func _anchor_cell_for(at_position: Vector2, shape: Array[Vector2i]) -> Vector2i:
	var cost := BattleCost.new(shape)
	var top_left_px := at_position - _shape_size_px(cost) / 2.0
	return pixel_to_cell(top_left_px) - cost.bounds_min()


## 拿起已放置角色:壓在該角色任一佔用格上皆可撿起,不限定佔位格(站立圖示)那一格
## ——比字面「拉動佔位格中的小人」寬容也更好操作,刻意簡化。撿起後可以拖到自己
## 目前佔用的其他格子上放開,改變哪一格是佔位格(can_place() 的 excluding_character
## 排除了自己目前佔用的格子,所以在自己形狀範圍內移動一定合法)。
func _get_drag_data(at_position: Vector2):
	if grid == null:
		return null
	var character := grid.get_character_at(pixel_to_cell(at_position))
	if character == null:
		return null

	var shape := grid.get_placement_shape(character)
	var preview := BattleCostView.build_centered_drag_preview(shape.duplicate(), PartyEditBoard.TILE_SIZE, character.weapon)
	set_drag_preview(preview)

	return {
		"type": "battle_cost_placement",
		"character": character,
		"shape": shape.duplicate(),
		"preview": preview,
		"origin": "grid",
	}


func _can_drop_data(at_position: Vector2, data) -> bool:
	if grid == null or typeof(data) != TYPE_DICTIONARY or data.get("type") != "battle_cost_placement":
		_hover_active = false
		return false

	var shape: Array[Vector2i] = data["shape"]
	var anchor := _anchor_cell_for(at_position, shape)
	var excluding: Character = data["character"] if data.get("origin") == "grid" else null

	_hover_active = true
	_hover_anchor = anchor
	_hover_shape = shape
	_hover_valid = grid.can_place(shape, anchor, excluding)
	queue_redraw()
	return _hover_valid


## 拖放的角色目前若派駐在根據地某棟建築生產,或正在歷練中,都不直接搶過來——先跳
## ConfirmDialog 問玩家是否要召回/取消歷練改編入小隊,確定才真的清掉舊狀態、place() 到
## 網格上(比照 Scenes/Base/worker_dispatch_panel.gd 的 _confirm_reassign() 同一套「跳確認
## 才生效」寫法,兩邊互斥規則要一致,見 CLAUDE.md 這次需求),取消的話網格維持原樣,不會出現
## 角色卡在畫面上但資料沒真的放置的中間態。派駐生產跟歷練中不會同時成立(見
## BaseDispatchStore.dispatch()/BarracksExpeditionStore.send() 的互斥判斷),兩個分支互斥。
func _drop_data(at_position: Vector2, data) -> void:
	var shape: Array[Vector2i] = data["shape"]
	var anchor := _anchor_cell_for(at_position, shape)
	var character: Character = data["character"]
	_hover_active = false
	queue_redraw()

	if BarracksExpeditionStore.is_on_expedition(character.id):
		ConfirmDialog.ask("%s 目前歷練中，取消歷練不會有任何歷練獎勵，是否改編入隊伍？" % character.display_name, func() -> void:
			BarracksExpeditionStore.recall(character.id)
			grid.place(character, shape, anchor)
			placement_changed.emit()
		, Callable(), "確定", "取消")
		return

	var dispatched_building_type := BaseDispatchStore.get_dispatched_building_type(character.id)
	if dispatched_building_type != -1:
		var building_name := GameEnums.building_type_label(dispatched_building_type)
		ConfirmDialog.ask("%s 目前在%s工作，是否改安排到隊伍中？" % [character.display_name, building_name], func() -> void:
			BaseDispatchStore.undispatch_character(character.id)
			grid.place(character, shape, anchor)
			placement_changed.emit()
		, Callable(), "確定", "取消")
		return

	grid.place(character, shape, anchor)
	placement_changed.emit()


## 單純點一下(沒有拖曳)已放置角色的格子,直接取消放置、退回候補清單;
## 右鍵點一下已放置角色的格子則是設為隊長(見 leader_change_requested)。
func _gui_input(event: InputEvent) -> void:
	if grid == null or not (event is InputEventMouseButton):
		return

	if event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			var character := grid.get_character_at(pixel_to_cell(event.position))
			if character != null:
				leader_change_requested.emit(character)
		return

	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	if event.pressed:
		_click_press_active = true
		_click_press_cell = pixel_to_cell(event.position)
		return

	if _click_press_active and not get_viewport().gui_is_dragging() and pixel_to_cell(event.position) == _click_press_cell:
		var character := grid.get_character_at(_click_press_cell)
		if character != null:
			grid.remove(character)
			placement_changed.emit()
	_click_press_active = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_hover_active = false
		_click_press_active = false
		queue_redraw()
