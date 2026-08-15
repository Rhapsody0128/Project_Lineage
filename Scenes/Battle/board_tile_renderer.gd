class_name BoardTileRenderer
extends RefCounted

# =========================================================
# 共用的棋盤格繪製(方格 + 格線)。Battle 的 BattleBoard 與
# PartyEdit 的 PartyEditBoard 共用同一套繪製邏輯,差異(格數/格子
# 大小/原點/每格顏色)透過參數與可選的逐格上色 callback 客製化,
# 呼叫端(某個 Control 的 _draw())把自己(canvas)傳進來畫。
# =========================================================

const DEFAULT_LINE_COLOR := Color(1, 1, 1, 0.45)

static func draw_board(
	canvas: CanvasItem,
	cols: int,
	rows: int,
	tile_size: float,
	origin: Vector2,
	tile_color_fn: Callable = Callable(),
	line_color: Color = DEFAULT_LINE_COLOR
) -> void:
	for y in range(rows):
		for x in range(cols):
			var top_left := origin + Vector2(x, y) * tile_size
			var rect := Rect2(top_left, Vector2(tile_size, tile_size))
			var color: Color = tile_color_fn.call(x, y) if tile_color_fn.is_valid() else _default_tile_color(x, y)
			canvas.draw_rect(rect, color)

	for x in range(cols + 1):
		var top := origin + Vector2(x * tile_size, 0)
		var bottom := origin + Vector2(x * tile_size, rows * tile_size)
		canvas.draw_line(top, bottom, line_color, 1.0)

	for y in range(rows + 1):
		var left := origin + Vector2(0, y * tile_size)
		var right := origin + Vector2(cols * tile_size, y * tile_size)
		canvas.draw_line(left, right, line_color, 1.0)

static func _default_tile_color(x: int, y: int) -> Color:
	var base_color := Color(0.28, 0.3, 0.38)
	if (x + y) % 2 == 0:
		return base_color.lightened(0.06)
	return base_color.darkened(0.06)

## 格子中心點/左上角點,格子座標→像素座標換算,Battle/PartyEdit 共用同一份公式
static func grid_to_pixel(gp: Vector2i, tile_size: float, origin: Vector2) -> Vector2:
	return grid_corner_to_pixel(gp, tile_size, origin) + Vector2(tile_size / 2.0, tile_size / 2.0)

static func grid_corner_to_pixel(gp: Vector2i, tile_size: float, origin: Vector2) -> Vector2:
	return origin + Vector2(gp.x * tile_size, gp.y * tile_size)
