class_name MapObjectData
extends RefCounted

## 大地圖上單一地點的資料(城堡等)。所有實體都集中在 get_all() 靜態工廠回傳,
## 不要把座標散落寫在 Map.tscn 或 MapSystem.gd。

var id: String
var name: String
var texture: Texture2D
var position: Vector2
var type: int


func _init(p_id: String, p_name: String, p_texture: Texture2D, p_position: Vector2, p_type: int) -> void:
	id = p_id
	name = p_name
	texture = p_texture
	position = p_position
	type = p_type


## 目前所有地圖物件的集中定義(第一版:兩座城堡)。texture 暫時給 null,
## 城堡畫面端用正方形色塊代替(見 Scenes/Map/map_object_visual.gd)。
static func get_all() -> Array[MapObjectData]:
	return [
		MapObjectData.new("castle_a", "王城", null, Vector2(1200, 900), GameEnums.MapObjectType.CASTLE),
		MapObjectData.new("castle_C", "王城B", null, Vector2(1200, 200), GameEnums.MapObjectType.CASTLE),
		MapObjectData.new("castle_b", "邊境城", null, Vector2(6800, 3600), GameEnums.MapObjectType.CASTLE),
	]
