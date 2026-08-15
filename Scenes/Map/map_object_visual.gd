class_name MapObjectVisual
extends Node2D

## 大地圖上單一 MapObjectData 的畫面呈現(城堡目前用正方形色塊暫代)。
## 只負責顯示,不做點擊判定——點擊命中測試統一由 MapSystem.pick_object()
## 處理(見 Scenes/Map/map.gd),避免多一套判定入口。

const CASTLE_SIZE := Vector2(160, 160)
const CASTLE_COLOR := Color(0.55, 0.45, 0.35)
const LABEL_OFFSET := Vector2(-80, -150)

var data: MapObjectData


func setup(p_data: MapObjectData) -> void:
	data = p_data
	position = data.position

	var square := ColorRect.new()
	square.size = CASTLE_SIZE
	square.position = -CASTLE_SIZE / 2.0
	square.color = CASTLE_COLOR if data.type == GameEnums.MapObjectType.CASTLE else Color.GRAY
	add_child(square)

	var label := Label.new()
	label.text = data.name
	label.position = LABEL_OFFSET
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	add_child(label)
