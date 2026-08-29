class_name BarracksFormationPartyBoard
extends Control

# =========================================================
# 兵營「變換隊形」畫面右側的縮小版隊伍站位預覽(見 barracks_formation_panel.gd),純唯讀
# 顯示,不含任何互動(格子解鎖狀態沿用 BarracksGridExpandPanel 同一套配色,已放置角色格子
# 額外疊色塊 + 頭像,隊長用金色跟其他隊員的藍色區分,寫法比照 party_edit.gd 的
# _refresh_placed_layer(),只是縮小尺寸、拿掉拖曳互動)。
# =========================================================

const TILE_SIZE := 32.0
const BOARD_ORIGIN := Vector2(4, 4)
const UNLOCKED_COLOR := Color(0.55, 0.75, 0.45, 0.5)
const LOCKED_COLOR := Color(0.32, 0.32, 0.36, 0.5)
const LEADER_CELL_COLOR := Color(0.95, 0.75, 0.4, 0.6)
const MEMBER_CELL_COLOR := Color(0.4, 0.6, 0.9, 0.55)


func _ready() -> void:
	custom_minimum_size = Vector2(
		BOARD_ORIGIN.x * 2 + TILE_SIZE * PartyEditGrid.GRID_COLS,
		BOARD_ORIGIN.y * 2 + TILE_SIZE * PartyEditGrid.GRID_ROWS
	)


func _draw() -> void:
	var grid := PartyStore.grid
	BoardTileRenderer.draw_board(
		self, PartyEditGrid.GRID_COLS, PartyEditGrid.GRID_ROWS, TILE_SIZE, BOARD_ORIGIN,
		func(x: int, y: int) -> Color:
			return UNLOCKED_COLOR if (grid != null and grid.is_unlocked(Vector2i(x, y))) else LOCKED_COLOR
	)

	if grid == null:
		return

	var leader := grid.get_leader()
	for character in grid.get_all_placed_characteres():
		var anchor: Vector2i = grid.get_placement_anchor(character)
		var shape: Array[Vector2i] = grid.get_placement_shape(character)
		var cell_color := LEADER_CELL_COLOR if character == leader else MEMBER_CELL_COLOR
		for offset in shape:
			var cell := anchor + offset
			var rect := Rect2(BOARD_ORIGIN + Vector2(cell.x, cell.y) * TILE_SIZE, Vector2(TILE_SIZE, TILE_SIZE))
			draw_rect(rect, cell_color)

		if character.face_path.is_empty():
			continue
		var texture := load(character.face_path) as Texture2D
		if texture == null:
			continue
		var anchor_rect := Rect2(BOARD_ORIGIN + Vector2(anchor.x, anchor.y) * TILE_SIZE, Vector2(TILE_SIZE, TILE_SIZE))
		draw_texture_rect(texture, anchor_rect, false)
