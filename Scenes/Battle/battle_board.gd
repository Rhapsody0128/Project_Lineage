class_name BattleBoard
extends Control

# =========================================================
# 棋盤地板 + 格線繪製(正面方格,無斜角投影)。
#
# 這是一個獨立的 Control 節點,插在場景樹裡 BoardPanel 之後、
# UnitsLayer 之前 —— 如果直接把 _draw() 寫在場景根節點上,
# 會被根節點自己的子節點(Background、BoardPanel 等不透明面板)
# 蓋在上面而完全看不見,所以格線/地板必須拆成獨立節點,
# 排在遮擋面板之後、角色圖層之前,才能正確疊在畫面上。
#
# 格子大小/佈陣全部由 System/battle 的 Battle 決定,本檔案只負責畫出來,
# 並提供 grid_to_pixel/grid_corner_to_pixel 給 battle.gd 換算單位座標。
# =========================================================

const GRID_COLS := Battle.GRID_COLS
const GRID_ROWS := Battle.GRID_ROWS

# 數值配合 battle.tscn 的 BoardPanel(140,140)-(968,620)置中,
# 12 欄 x 6 列 x 65px 置中後留白。
const TILE_SIZE := 65.0
const BOARD_ORIGIN := Vector2(164, 185)

const GROUND_COLOR_SELF := Color(0.30, 0.42, 0.24)
const GROUND_COLOR_ENEMY := Color(0.42, 0.30, 0.24)
const GROUND_SHADE_OFFSET := 0.06

const GRID_LINE_COLOR := Color(1, 1, 1, 0.45)
const MID_LINE_COLOR := Color(1, 1, 0, 0.5)


func _draw() -> void:
	_draw_ground_tiles()
	_draw_grid_lines()


## 每一格畫成一個正方形(依格子座標的四個角),
## 用棋盤式明暗交錯 + 我方(左)/敵方(右)陣營底色,呈現出「地板」的感覺。
func _draw_ground_tiles() -> void:
	var mid_x := GRID_COLS / 2

	for y in range(GRID_ROWS):
		for x in range(GRID_COLS):
			var top_left := grid_corner_to_pixel(Vector2i(x, y))
			var rect := Rect2(top_left, Vector2(TILE_SIZE, TILE_SIZE))

			var base_color := GROUND_COLOR_SELF if x < mid_x else GROUND_COLOR_ENEMY
			if (x + y) % 2 == 0:
				base_color = base_color.lightened(GROUND_SHADE_OFFSET)
			else:
				base_color = base_color.darkened(GROUND_SHADE_OFFSET)

			draw_rect(rect, base_color)


func _draw_grid_lines() -> void:
	for x in range(GRID_COLS + 1):
		draw_line(
			grid_corner_to_pixel(Vector2i(x, 0)),
			grid_corner_to_pixel(Vector2i(x, GRID_ROWS)),
			GRID_LINE_COLOR,
			1.0
		)

	for y in range(GRID_ROWS + 1):
		draw_line(
			grid_corner_to_pixel(Vector2i(0, y)),
			grid_corner_to_pixel(Vector2i(GRID_COLS, y)),
			GRID_LINE_COLOR,
			1.0
		)

	# 中線,標示雙方交戰的中央地帶
	var mid_x := GRID_COLS / 2
	draw_line(
		grid_corner_to_pixel(Vector2i(mid_x, 0)),
		grid_corner_to_pixel(Vector2i(mid_x, GRID_ROWS)),
		MID_LINE_COLOR,
		2.0
	)


## 格子中心點(單位顯示位置用)
func grid_to_pixel(gp: Vector2i) -> Vector2:
	return grid_corner_to_pixel(gp) + Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0)


## 格子左上角點(畫格線/地板用)
func grid_corner_to_pixel(gp: Vector2i) -> Vector2:
	return BOARD_ORIGIN + Vector2(gp.x * TILE_SIZE, gp.y * TILE_SIZE)
