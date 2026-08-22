@tool
class_name CastleMapIcon
extends Node2D

## 大地圖上單一城堡的圖示,結構與行為比照 Scenes/MapObject/Town/town.gd 的 TownMapIcon——
## 手動擺放在 Scenes/Map/map.tscn,座標由美術直接拖曳決定(見 Scenes/Map/map.gd 的
## _sync_map_object_positions()),terrain 是根節點匯出屬性,每個實例各自 override 一份。

@export var terrain: GameEnums.TerrainType = GameEnums.TerrainType.PLAINS:
	set(value):
		terrain = value
		_apply_texture()


func _ready() -> void:
	_apply_texture()


func _apply_texture() -> void:
	if not is_node_ready():
		return
	$Sprite2D.texture = load(GameEnums.castle_map_icon_path(terrain))
