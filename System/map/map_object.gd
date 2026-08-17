class_name MapObject
extends RefCounted

## 大地圖上單一地點的資料(城鎮等)。所有實體都集中在 get_all() 靜態工廠回傳,
## 不要把座標散落寫在 map.tscn 或 map_system.gd。

var id: String
var name: String
var texture: Texture2D
var position: Vector2
var type: int
## 該地點所屬勢力的領土邊界(世界座標,PackedVector2Array 多邊形頂點),供 territory
## 渲染/點擊判定使用(見 MapSystem.pick_object())。position 是這個多邊形的外框中心點
## (bounding box center),同一個世界座標系,兩者對得上。
var territory_polygon: PackedVector2Array


func _init(p_id: String, p_name: String, p_texture: Texture2D, p_position: Vector2, p_type: int, p_territory_polygon: PackedVector2Array = PackedVector2Array()) -> void:
	id = p_id
	name = p_name
	texture = p_texture
	position = p_position
	type = p_type
	territory_polygon = p_territory_polygon


## 目前所有地圖物件的集中定義(三座城鎮+玩家根據地)。texture 暫時給 null,
## 地圖8000*4500
## 城鎮畫面端用正方形色塊代替(見 Scenes/Map/map_object_visual.gd)。
static func get_all() -> Array[MapObject]:
	return [
		MapObject.new("LionTown", "獅城", null, Vector2(1325.0, 814.0), GameEnums.MapObjectType.TOWN, PackedVector2Array([Vector2(549.9998, 1151.0001), Vector2(757.9998, 1247.0001), Vector2(915.9998, 1363.0001), Vector2(1028.9998, 1351.0001), Vector2(1141.9998, 1397.0002), Vector2(1572.9998, 1432.0002), Vector2(1894.9998, 1345.0004), Vector2(2099.9998, 1222.0004), Vector2(2088.9998, 948.0004), Vector2(1879.9999, 832.0003), Vector2(1767.9999, 780.0003), Vector2(1675.9999, 600.0003), Vector2(1601.9999, 411.0003), Vector2(1314.9999, 405.0002), Vector2(1257.0, 196.0002), Vector2(1230.9999, 408.0002), Vector2(1205.9999, 589.0002), Vector2(1146.9999, 496.0002), Vector2(1097.9999, 600.0002), Vector2(1007.9999, 614.0002), Vector2(971.9999, 742.0002), Vector2(877.9999, 755.0001), Vector2(793.9999, 864.0001), Vector2(703.9998, 935.0001), Vector2(566.9998, 1040.0001), Vector2(562.9998, 1123.0001)])),
		MapObject.new("BearTown", "雄城", null, Vector2(1183.0, 2925.0), GameEnums.MapObjectType.TOWN, PackedVector2Array([Vector2(407.9995, 3200.0001), Vector2(615.9994, 3296.0001), Vector2(773.9994, 3412.0001), Vector2(886.9994, 3400.0001), Vector2(999.9995, 3446.0002), Vector2(1430.9995, 3481.0002), Vector2(1752.9995, 3394.0004), Vector2(1957.9995, 3271.0004), Vector2(1946.9995, 2997.0004), Vector2(1737.9995, 2881.0003), Vector2(1625.9995, 2829.0003), Vector2(1441.9995, 2747.0003), Vector2(1459.9995, 2460.0003), Vector2(1172.9995, 2454.0002), Vector2(1251.9996, 2420.0002), Vector2(1118.9996, 2395.0002), Vector2(1067.9996, 2420.0002), Vector2(1020.9996, 2435.0002), Vector2(961.9996, 2369.0002), Vector2(955.9995, 2649.0002), Vector2(865.9995, 2663.0002), Vector2(829.9995, 2791.0002), Vector2(735.9995, 2804.0001), Vector2(651.9995, 2913.0001), Vector2(561.9995, 2984.0001), Vector2(424.9995, 3089.0001), Vector2(420.9995, 3172.0001)])),
		MapObject.new("EagleTown", "鷹城", null, Vector2(3978.0, 640.5), GameEnums.MapObjectType.TOWN, PackedVector2Array([Vector2(3337.9998, 1048.0006), Vector2(3502.9998, 1124.0006), Vector2(3714.9998, 1095.0006), Vector2(3944.9998, 1072.0007), Vector2(4046.9998, 1002.0007), Vector2(4285.0, 1018.0007), Vector2(4418.0, 1072.0007), Vector2(4576.0, 1018.0008), Vector2(4680.0, 894.0008), Vector2(4494.0, 768.0008), Vector2(4299.0, 649.0007), Vector2(4155.0, 560.0007), Vector2(4136.0, 346.0007), Vector2(4136.0, 170.0007), Vector2(3874.0, 157.0007), Vector2(3772.0, 157.0007), Vector2(3804.0, 285.0007), Vector2(3746.0, 374.0006), Vector2(3644.0, 434.0006), Vector2(3640.0, 556.0006), Vector2(3618.0, 656.0006), Vector2(3478.9998, 740.0006), Vector2(3275.9998, 855.0005), Vector2(3288.9998, 989.0005), Vector2(3316.9998, 1031.0006)])),
		MapObject.new("PlayerBase", "根據地", null, Vector2(4029.0, 1967.5007), GameEnums.MapObjectType.BASE, PackedVector2Array([Vector2(3749.9998, 1927.0006), Vector2(3888.9998, 1806.0007), Vector2(4028.9998, 1655.0007), Vector2(4080.9998, 1800.0007), Vector2(4171.9995, 1919.0007), Vector2(4311.9995, 1984.0007), Vector2(4365.9995, 2037.0007), Vector2(4276.9995, 2198.0007), Vector2(4219.9995, 2278.0007), Vector2(3997.9995, 2280.0007), Vector2(3779.9995, 2247.0007), Vector2(3691.9995, 2108.0007)])),
	]


## 各地點類型底下的子地點清單(見 Scenes/MapLocation/)。地點不一定是城鎮(之後會有
## 村莊/遺跡等其他 type),子地點內容一律照 type 查表決定,不要在 Scenes/MapLocation/
## 寫死特定地點類型的選項文字。TOWN:城門/酒館/市集是佔位按鈕,聊天已接上
## DialogueBox、休息已接上「退回大地圖並讓時間流逝」(見 Scenes/MapLocation/
## map_location.gd)。BASE(玩家根據地)只有一個「進入根據地」子地點,按下去切去
## Scenes/Base/base.tscn,建築內政系統(遊戲企劃設定總整理.md 六十八節)實際邏輯在
## 那個場景裡,不在這個地點選單。
const TYPE_SUB_LOCATIONS: Dictionary = {
	GameEnums.MapObjectType.TOWN: ["城門", "酒館", "市集", "聊天", "休息"],
	GameEnums.MapObjectType.BASE: ["進入根據地"],
}


static func get_sub_locations(type: int) -> Array[String]:
	var labels: Array[String] = []
	labels.assign(TYPE_SUB_LOCATIONS.get(type, []))
	return labels
