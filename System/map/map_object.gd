class_name MapObject
extends RefCounted

## 大地圖上單一地點的資料(城鎮等)。所有實體都集中在 get_all() 靜態工廠回傳,不要把
## nation/type/子地點清單這類規則資料散落寫在 map.tscn 或 map_system.gd。城鎮跟根據地的
## position 例外——那是美術在 map.tscn 拖節點決定的,這裡只保留同步過來的快照,見
## get_all() 下方註解與 Scenes/Map/map.gd 的 _sync_map_object_positions()。

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
## 自身國家血統,等那個功能接上再改成真正的選擇結果。CASTLE 不屬於特定國家(同一地形
## 有兩座),這裡純粹借該地形對應的 nation 當查表 key,不代表城堡效忠哪個國家。
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


## 目前所有地圖物件的集中定義(六座城鎮+玩家根據地+十二座城堡,每種地形兩座)。
## texture 暫時給 null。
##
## 城鎮/根據地/城堡的 position 不是這裡手算的——實際座標由美術直接在 Scenes/Map/
## map.tscn 拖曳對應的場景節點(Town_Lion/.../Base/Castle_Plains_1/...,分別是
## Scenes/MapObject/Town/Town.tscn、Base/Base.tscn、Castle/Castle.tscn 的實例)決定,
## 這裡的數值是那些節點目前的座標快照,只是給 RoamingEnemySpawner
## (System/map/roaming_enemy_spawner.gd 的 _nearest_town_nation(),獨立呼叫 get_all()、
## 不會經過 map.gd)這類拿不到場景樹的 System 層邏輯讀。之後只要在編輯器重新拖動這些
## 節點,記得把這裡對應的座標也同步改掉,否則遊蕩敵人歸屬國家等判定會跟畫面對不上。
## 都不再用領土多邊形(舊多邊形是對照舊版地圖美術手繪,換圖後已經跟畫面對不上,直接
## 拿掉),點擊判定退回 MapSystem.pick_object() 的 position + radius 判定,畫面本身就是
## map.tscn 裡那些手動擺放的節點,不再由 MapObjectVisual 產生。
static func get_all() -> Array[MapObject]:
	return [
		MapObject.new("LionTown", "獅城", null, Vector2(2069.9995, 2842.0002), GameEnums.MapObjectType.TOWN, GameEnums.BloodlineNation.LION),
		MapObject.new("BearTown", "雄城", null, Vector2(4069.9995, 2427.0007), GameEnums.MapObjectType.TOWN, GameEnums.BloodlineNation.BEAR),
		MapObject.new("EagleTown", "鷹城", null, Vector2(6076.0, 1064.0011), GameEnums.MapObjectType.TOWN, GameEnums.BloodlineNation.EAGLE),
		MapObject.new("DragonTown", "龍城", null, Vector2(1566.9998, 1373.0004), GameEnums.MapObjectType.TOWN, GameEnums.BloodlineNation.DRAGON),
		MapObject.new("DeerTown", "鹿城", null, Vector2(4238.0, 530.00073), GameEnums.MapObjectType.TOWN, GameEnums.BloodlineNation.DEER),
		MapObject.new("LeopardTown", "豹城", null, Vector2(6874.9995, 2519.0012), GameEnums.MapObjectType.TOWN, GameEnums.BloodlineNation.LEOPARD),
		# nation 暫定 LION——玩家目前沒有可選的自身國家血統,根據地地點選單背景圖固定用
		# GameEnums.BASE_LOCATION_BACKGROUND_PATH,不吃這個 nation 換算的地形,等玩家
		# 可選血統國家的功能接上再視需要改成真正的選擇結果。
		MapObject.new("PlayerBase", "根據地", null, Vector2(2733.9995, 1810.0005), GameEnums.MapObjectType.BASE, GameEnums.BloodlineNation.LION),
		# 十二座城堡,每種地形各兩座。nation 純粹借地形對應的國家當查表 key(見上方 nation
		# 欄位註解),不代表城堡效忠哪國。
		MapObject.new("PlainsCastle1", "平原城堡1", null, Vector2(1218.9996, 2387.0002), GameEnums.MapObjectType.CASTLE, GameEnums.BloodlineNation.LION),
		MapObject.new("PlainsCastle2", "平原城堡2", null, Vector2(3093.9995, 3302.0005), GameEnums.MapObjectType.CASTLE, GameEnums.BloodlineNation.LION),
		MapObject.new("MountainsCastle1", "山岳城堡1", null, Vector2(4628.9995, 2997.0007), GameEnums.MapObjectType.CASTLE, GameEnums.BloodlineNation.BEAR),
		MapObject.new("MountainsCastle2", "山岳城堡2", null, Vector2(5890.9995, 3314.001), GameEnums.MapObjectType.CASTLE, GameEnums.BloodlineNation.BEAR),
		MapObject.new("PlateauCastle1", "高原城堡1", null, Vector2(3725.9998, 1096.0006), GameEnums.MapObjectType.CASTLE, GameEnums.BloodlineNation.DEER),
		MapObject.new("PlateauCastle2", "高原城堡2", null, Vector2(5088.0, 651.00085), GameEnums.MapObjectType.CASTLE, GameEnums.BloodlineNation.DEER),
		MapObject.new("ForestCastle1", "森林城堡1", null, Vector2(6912.9995, 1625.0012), GameEnums.MapObjectType.CASTLE, GameEnums.BloodlineNation.EAGLE),
		MapObject.new("ForestCastle2", "森林城堡2", null, Vector2(5198.9995, 1312.001), GameEnums.MapObjectType.CASTLE, GameEnums.BloodlineNation.EAGLE),
		MapObject.new("DesertCastle1", "沙漠城堡1", null, Vector2(6261.9995, 3033.0012), GameEnums.MapObjectType.CASTLE, GameEnums.BloodlineNation.LEOPARD),
		MapObject.new("DesertCastle2", "沙漠城堡2", null, Vector2(5616.9995, 2088.001), GameEnums.MapObjectType.CASTLE, GameEnums.BloodlineNation.LEOPARD),
		MapObject.new("IcefieldCastle1", "冰原城堡1", null, Vector2(865.9999, 661.0002), GameEnums.MapObjectType.CASTLE, GameEnums.BloodlineNation.DRAGON),
		MapObject.new("IcefieldCastle2", "冰原城堡2", null, Vector2(2224.0, 807.0004), GameEnums.MapObjectType.CASTLE, GameEnums.BloodlineNation.DRAGON),
	]


## 各地點類型底下的子地點清單(見 Scenes/MapLocation/)。地點不一定是城鎮(之後會有
## 村莊/遺跡等其他 type),子地點內容一律照 type 查表決定,不要在 Scenes/MapLocation/
## 寫死特定地點類型的選項文字。TOWN:城門/酒館/市集是佔位按鈕,聊天已接上
## DialogueBox、休息已接上「退回大地圖並讓時間流逝」(見 Scenes/MapLocation/
## map_location.gd)。BASE(玩家根據地)除了「進入根據地」(切去 Scenes/Base/base.tscn,
## 建築內政系統的實際邏輯在那個場景裡,不在這個地點選單)之外,也共用同一個「休息」
## 按鈕邏輯——按鈕文字字串相同,map_location.gd 用文字比對接同一支
## _on_rest_button_pressed(),不需要分 TOWN/BASE 另外寫一份。BASE 專屬多一顆「長休」:
## 彈出面板讓玩家指定 1~365 天,確定後一樣退回大地圖播放時間,但額外把倍速直接調到
## DEMO(100 倍),直到指定天數到達或玩家提早移動/操作(視同一般休息醒來)才把倍速還原
## 成 1 倍——實際到站判定/倍速還原都在 Scenes/Map/map.gd(MapSessionStore.
## long_rest_target_day),這裡只負責在子選單多列一顆按鈕。CASTLE:駐軍是佔位按鈕;
## 聊天跟 TOWN 同名但故意不共用 TownChatEvent(map_location.gd 的 CHAT_LABEL 分支額外
## 檢查 type == TOWN 才接,見該檔案註解),先當佔位按鈕,城堡專屬聊天內容之後再設計;
## 休息比照 TOWN/BASE 共用同一支 _on_rest_button_pressed()。
const TYPE_SUB_LOCATIONS: Dictionary = {
	GameEnums.MapObjectType.TOWN: ["城門", "酒館", "市集", "聊天", "休息"],
	GameEnums.MapObjectType.BASE: ["進入根據地", "休息", "長休"],
	GameEnums.MapObjectType.CASTLE: ["聊天", "駐軍", "休息"],
}


## castle_conquered 只在 type == CASTLE 時有意義:城堡還沒被玩家攻下時,子選單只留
## 「聊天」(觸發 System/event/castle/castle_siege_event.gd 的攻城流程),駐軍/休息要等
## 攻下後才開放,呼叫端(Scenes/MapLocation/map_location.gd)依 CastleStore.is_conquered()
## 決定要傳 true 還是 false,這裡不直接依賴 CastleStore(System/ 不碰 Scripts/Autoload
## 的 session 狀態,比照 NationFavorRank 只吃參數的慣例)。
static func get_sub_locations(type: int, castle_conquered: bool = true) -> Array[String]:
	if type == GameEnums.MapObjectType.CASTLE and not castle_conquered:
		return ["聊天"]
	var labels: Array[String] = []
	labels.assign(TYPE_SUB_LOCATIONS.get(type, []))
	return labels
