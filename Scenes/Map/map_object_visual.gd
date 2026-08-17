class_name MapObjectVisual
extends Node2D

## 大地圖上單一 MapObject 的畫面呈現:有 territory_polygon 的地點畫領土多邊形,
## 沒有的暫用正方形色塊代替——一個地點只會有其中一種圖形,不會兩個同時畫。
## 只負責顯示,不做點擊判定——點擊命中測試統一由 MapSystem.pick_object()
## 處理(見 Scenes/Map/map.gd),避免多一套判定入口。

const TOWN_SIZE := Vector2(160, 160)
const TOWN_COLOR := Color(0.55, 0.45, 0.35)
const TERRITORY_COLOR := Color(0.55, 0.45, 0.35, 0.12)
const LABEL_OFFSET := Vector2(-80, -150)

var data: MapObject


func setup(p_data: MapObject) -> void:
	data = p_data
	position = data.position

	if data.territory_polygon.is_empty():
		_add_square()
	else:
		_add_territory_polygon()

	var label := Label.new()
	label.text = data.name
	label.position = LABEL_OFFSET
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)


func _add_square() -> void:
	var square := ColorRect.new()
	square.size = TOWN_SIZE
	square.position = -TOWN_SIZE / 2.0
	square.color = TOWN_COLOR if data.type == GameEnums.MapObjectType.TOWN else Color.GRAY
	# Control 預設 mouse_filter = STOP,會把滑鼠事件吃掉、傳不到 map.gd 的
	# _unhandled_input(),導致點正方形本身沒反應、點旁邊反而有反應(因為
	# 落在 pick_object() 的圓形判定範圍內但沒被這個 Control 攔截)。這裡純
	# 顯示不做點擊判定,一律忽略滑鼠事件。
	square.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(square)


## territory_polygon 存的是世界座標,這裡的節點已經因為 position = data.position
## 平移過一次,所以要扣掉 data.position 換算回節點的本地座標,才不會疊加位移。
func _add_territory_polygon() -> void:
	var polygon := Polygon2D.new()
	var local_points := PackedVector2Array()
	local_points.resize(data.territory_polygon.size())
	for i in data.territory_polygon.size():
		local_points[i] = data.territory_polygon[i] - data.position
	polygon.polygon = local_points
	polygon.color = TERRITORY_COLOR
	add_child(polygon)
