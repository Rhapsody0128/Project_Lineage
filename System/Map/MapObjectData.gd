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
## 地圖8000*4500
## 城堡畫面端用正方形色塊代替(見 Scenes/Map/map_object_visual.gd)。
static func get_all() -> Array[MapObjectData]:
	return [
		MapObjectData.new("castle_a", "王城", null, Vector2(1200, 900), GameEnums.MapObjectType.CASTLE),
		MapObjectData.new("castle_C", "王城B", null, Vector2(1200, 200), GameEnums.MapObjectType.CASTLE),
		MapObjectData.new("castle_b", "邊境城", null, Vector2(6800, 3600), GameEnums.MapObjectType.CASTLE),
	]


## 各地點類型底下的子地點清單(見 Scenes/MapLocation/)。地點不一定是城堡(之後會有
## 村莊/遺跡等其他 type),子地點內容一律照 type 查表決定,不要在 Scenes/MapLocation/
## 寫死特定地點類型的選項文字。目前只有 CASTLE 一種 type;城堡/酒館/市集是佔位按鈕,
## 聊天已接上 DialogueBox(見 Scenes/MapLocation/map_location.gd)。
const TYPE_SUB_LOCATIONS: Dictionary = {
	GameEnums.MapObjectType.CASTLE: ["城堡", "酒館", "市集", "聊天"],
}


static func get_sub_locations(type: int) -> Array[String]:
	var labels: Array[String] = []
	labels.assign(TYPE_SUB_LOCATIONS.get(type, []))
	return labels
