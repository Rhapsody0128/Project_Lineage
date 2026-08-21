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
## GameEnums.BloodlineNation,決定這個地點的代表地形(見 terrain_type())——TOWN 對應
## 該城鎮所屬的文明國家;BASE(玩家根據地)目前借用 LION 當預設外觀,玩家還沒有可選的
## 自身國家血統,等那個功能接上再改成真正的選擇結果。
var nation: int


func _init(p_id: String, p_name: String, p_texture: Texture2D, p_position: Vector2, p_type: int, p_nation: int, p_territory_polygon: PackedVector2Array = PackedVector2Array()) -> void:
	id = p_id
	name = p_name
	texture = p_texture
	position = p_position
	type = p_type
	nation = p_nation
	territory_polygon = p_territory_polygon


## 這個地點代表的地理環境,由 nation 對照 GameEnums.bloodline_nation_terrain() 換算——
## Scenes/MapLocation/map_location.gd 進到 TOWN 地點選單挑對應地形背景圖(見
## GameEnums.town_background_path())時呼叫這裡,不要自己重複查表。
func terrain_type() -> int:
	return GameEnums.bloodline_nation_terrain(nation)


## 目前所有地圖物件的集中定義(六座城鎮+玩家根據地)。texture 暫時給 null,
## 地圖8000*4500
## 城鎮畫面端用正方形色塊代替(見 Scenes/Map/map_object_visual.gd)。position 一律是
## territory_polygon 的外框中心點(bounding box center,min/max 座標平均),不是隨手挑的
## 座標,新增城鎮時比照這個算法算 position,不要用多邊形頂點的算術平均。
static func get_all() -> Array[MapObject]:
	return [
		MapObject.new("LionTown", "獅城", null, Vector2(1325.0, 814.0), GameEnums.MapObjectType.TOWN, GameEnums.BloodlineNation.LION, PackedVector2Array([Vector2(549.9998, 1151.0001), Vector2(757.9998, 1247.0001), Vector2(915.9998, 1363.0001), Vector2(1028.9998, 1351.0001), Vector2(1141.9998, 1397.0002), Vector2(1572.9998, 1432.0002), Vector2(1894.9998, 1345.0004), Vector2(2099.9998, 1222.0004), Vector2(2088.9998, 948.0004), Vector2(1879.9999, 832.0003), Vector2(1767.9999, 780.0003), Vector2(1675.9999, 600.0003), Vector2(1601.9999, 411.0003), Vector2(1314.9999, 405.0002), Vector2(1257.0, 196.0002), Vector2(1230.9999, 408.0002), Vector2(1205.9999, 589.0002), Vector2(1146.9999, 496.0002), Vector2(1097.9999, 600.0002), Vector2(1007.9999, 614.0002), Vector2(971.9999, 742.0002), Vector2(877.9999, 755.0001), Vector2(793.9999, 864.0001), Vector2(703.9998, 935.0001), Vector2(566.9998, 1040.0001), Vector2(562.9998, 1123.0001)])),
		MapObject.new("BearTown", "雄城", null, Vector2(1183.0, 2925.0), GameEnums.MapObjectType.TOWN, GameEnums.BloodlineNation.BEAR, PackedVector2Array([Vector2(407.9995, 3200.0001), Vector2(615.9994, 3296.0001), Vector2(773.9994, 3412.0001), Vector2(886.9994, 3400.0001), Vector2(999.9995, 3446.0002), Vector2(1430.9995, 3481.0002), Vector2(1752.9995, 3394.0004), Vector2(1957.9995, 3271.0004), Vector2(1946.9995, 2997.0004), Vector2(1737.9995, 2881.0003), Vector2(1625.9995, 2829.0003), Vector2(1441.9995, 2747.0003), Vector2(1459.9995, 2460.0003), Vector2(1172.9995, 2454.0002), Vector2(1251.9996, 2420.0002), Vector2(1118.9996, 2395.0002), Vector2(1067.9996, 2420.0002), Vector2(1020.9996, 2435.0002), Vector2(961.9996, 2369.0002), Vector2(955.9995, 2649.0002), Vector2(865.9995, 2663.0002), Vector2(829.9995, 2791.0002), Vector2(735.9995, 2804.0001), Vector2(651.9995, 2913.0001), Vector2(561.9995, 2984.0001), Vector2(424.9995, 3089.0001), Vector2(420.9995, 3172.0001)])),
		MapObject.new("EagleTown", "鷹城", null, Vector2(3978.0, 640.5), GameEnums.MapObjectType.TOWN, GameEnums.BloodlineNation.EAGLE, PackedVector2Array([Vector2(3337.9998, 1048.0006), Vector2(3502.9998, 1124.0006), Vector2(3714.9998, 1095.0006), Vector2(3944.9998, 1072.0007), Vector2(4046.9998, 1002.0007), Vector2(4285.0, 1018.0007), Vector2(4418.0, 1072.0007), Vector2(4576.0, 1018.0008), Vector2(4680.0, 894.0008), Vector2(4494.0, 768.0008), Vector2(4299.0, 649.0007), Vector2(4155.0, 560.0007), Vector2(4136.0, 346.0007), Vector2(4136.0, 170.0007), Vector2(3874.0, 157.0007), Vector2(3772.0, 157.0007), Vector2(3804.0, 285.0007), Vector2(3746.0, 374.0006), Vector2(3644.0, 434.0006), Vector2(3640.0, 556.0006), Vector2(3618.0, 656.0006), Vector2(3478.9998, 740.0006), Vector2(3275.9998, 855.0005), Vector2(3288.9998, 989.0005), Vector2(3316.9998, 1031.0006)])),
		MapObject.new("DragonTown", "龍城", null, Vector2(3963.0, 3192.0), GameEnums.MapObjectType.TOWN, GameEnums.BloodlineNation.DRAGON, PackedVector2Array([Vector2(2905.9995, 3353.0005), Vector2(3294.9993, 3551.0005), Vector2(3675.9993, 3812.0007), Vector2(4307.9995, 3824.0007), Vector2(4956.9995, 3615.001), Vector2(5019.9995, 3255.001), Vector2(4401.9995, 2848.0007), Vector2(3992.9995, 2560.0007), Vector2(3551.9995, 2635.0007), Vector2(3554.9995, 3002.0007), Vector2(2921.9995, 3117.0005)])),
		MapObject.new("DeerTown", "鹿城", null, Vector2(6790.0, 3013.5), GameEnums.MapObjectType.TOWN, GameEnums.BloodlineNation.DEER, PackedVector2Array([Vector2(5831.9995, 3088.001), Vector2(6185.9995, 3229.001), Vector2(6322.9995, 3381.0012), Vector2(6676.9995, 3537.0012), Vector2(7159.9995, 3592.0012), Vector2(7540.9995, 3348.0012), Vector2(7772.9995, 3220.0015), Vector2(7451.9995, 2969.0012), Vector2(7624.9995, 2778.0012), Vector2(7287.9995, 2575.0012), Vector2(7070.9995, 2435.0012), Vector2(6811.9995, 2498.0012), Vector2(6480.9995, 2505.0012), Vector2(6033.9995, 2446.001), Vector2(5806.9995, 2641.001)])),
		MapObject.new("LeopardTown", "豹城", null, Vector2(6556.5, 990.0), GameEnums.MapObjectType.TOWN, GameEnums.BloodlineNation.LEOPARD, PackedVector2Array([Vector2(5816.9995, 1397.001), Vector2(6283.9995, 1571.0011), Vector2(6883.9995, 1465.0012), Vector2(7452.0, 1274.0013), Vector2(7233.0, 1009.0013), Vector2(7083.0, 775.0012), Vector2(6723.0, 739.00116), Vector2(6754.0, 409.0012), Vector2(6379.0, 420.00113), Vector2(6394.0, 775.0011), Vector2(5971.0, 903.00104), Vector2(5661.0, 1172.001), Vector2(5820.0, 1378.001)])),
		# nation 暫定 LION——玩家目前沒有可選的自身國家血統,根據地地點選單背景圖固定用
		# GameEnums.BASE_LOCATION_BACKGROUND_PATH,不吃這個 nation 換算的地形,等玩家
		# 可選血統國家的功能接上再視需要改成真正的選擇結果。
		MapObject.new("PlayerBase", "根據地", null, Vector2(4029.0, 1967.5007), GameEnums.MapObjectType.BASE, GameEnums.BloodlineNation.LION, PackedVector2Array([Vector2(3749.9998, 1927.0006), Vector2(3888.9998, 1806.0007), Vector2(4028.9998, 1655.0007), Vector2(4080.9998, 1800.0007), Vector2(4171.9995, 1919.0007), Vector2(4311.9995, 1984.0007), Vector2(4365.9995, 2037.0007), Vector2(4276.9995, 2198.0007), Vector2(4219.9995, 2278.0007), Vector2(3997.9995, 2280.0007), Vector2(3779.9995, 2247.0007), Vector2(3691.9995, 2108.0007)])),
	]


## 各地點類型底下的子地點清單(見 Scenes/MapLocation/)。地點不一定是城鎮(之後會有
## 村莊/遺跡等其他 type),子地點內容一律照 type 查表決定,不要在 Scenes/MapLocation/
## 寫死特定地點類型的選項文字。TOWN:城門/酒館/市集是佔位按鈕,聊天已接上
## DialogueBox、休息已接上「退回大地圖並讓時間流逝」(見 Scenes/MapLocation/
## map_location.gd)。BASE(玩家根據地)除了「進入根據地」(切去 Scenes/Base/base.tscn,
## 建築內政系統的實際邏輯在那個場景裡,不在這個地點選單)之外,也共用同一個「休息」
## 按鈕邏輯——按鈕文字字串相同,map_location.gd 用文字比對接同一支
## _on_rest_button_pressed(),不需要分 TOWN/BASE 另外寫一份。
const TYPE_SUB_LOCATIONS: Dictionary = {
	GameEnums.MapObjectType.TOWN: ["城門", "酒館", "市集", "聊天", "休息"],
	GameEnums.MapObjectType.BASE: ["進入根據地", "休息"],
}


static func get_sub_locations(type: int) -> Array[String]:
	var labels: Array[String] = []
	labels.assign(TYPE_SUB_LOCATIONS.get(type, []))
	return labels
