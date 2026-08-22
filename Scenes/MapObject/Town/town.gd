@tool
class_name TownMapIcon
extends Node2D

## 大地圖上單一城鎮的圖示(手動擺放在 Scenes/Map/map.tscn,座標由美術直接拖曳決定,
## 不是程式生成——見 Scenes/Map/map.gd 的 _sync_town_positions())。terrain 是根節點
## 匯出屬性,每個實例在 map.tscn 各自 override 一份,才能撐過編輯器存檔(巢狀子節點的
## property override 沒標記 editable children 存檔會被編輯器清掉,根節點匯出屬性才穩定)。

@export var terrain: GameEnums.TerrainType = GameEnums.TerrainType.PLAINS:
	set(value):
		terrain = value
		_apply_texture()


func _ready() -> void:
	_apply_texture()


func _apply_texture() -> void:
	if not is_node_ready():
		return
	$Sprite2D.texture = load(GameEnums.town_map_icon_path(terrain))
