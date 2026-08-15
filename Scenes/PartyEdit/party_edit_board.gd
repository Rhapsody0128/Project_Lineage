class_name PartyEditBoard
extends Control

# =========================================================
# PartyEdit 左側 6x6 網格的地板/格線繪製,呼叫共用的
# BoardTileRenderer(跟 Battle 的 BattleBoard 共用同一份繪製邏輯,
# 只是格數/大小/原點不同,配色沿用預設中性棋盤灰階)。
#
# 編成畫面只呈現玩家自己這一方,不畫敵方那半戰場——座標系跟 Battle
# 的自身區同一套(見 PartyEditGrid 開頭註解)。
#
# 純視覺,不含任何互動——格子是否可放置的反灰提示、拖曳放置判定
# 都是另一層 PartyEditAvailabilityLayer 的事,不是這裡的責任。
# =========================================================

# 配合 party_edit.tscn 的 BoardPanel 區域(140,140)-(968,620)置中,
# 6 欄 x 6 列 x 80px 置中後留白。
const TILE_SIZE := 80.0
const BOARD_ORIGIN := Vector2(314, 140)


func _draw() -> void:
	BoardTileRenderer.draw_board(self, PartyEditGrid.GRID_COLS, PartyEditGrid.GRID_ROWS, TILE_SIZE, BOARD_ORIGIN)


func grid_to_pixel(gp: Vector2i) -> Vector2:
	return BoardTileRenderer.grid_to_pixel(gp, TILE_SIZE, BOARD_ORIGIN)


func grid_corner_to_pixel(gp: Vector2i) -> Vector2:
	return BoardTileRenderer.grid_corner_to_pixel(gp, TILE_SIZE, BOARD_ORIGIN)


func pixel_to_cell(local_pos: Vector2) -> Vector2i:
	var p := (local_pos - BOARD_ORIGIN) / TILE_SIZE
	return Vector2i(floori(p.x), floori(p.y))
