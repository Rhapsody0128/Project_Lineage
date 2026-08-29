class_name BuildingPositions
extends RefCounted

## 根據地建築的畫面座標資料——跟 BuildingLibrary 的遊戲數值(名稱/描述/耗材/產出等)
## 分開放,這裡只放「這棟建築在背景圖上的外框多邊形」,不然座標數字會把
## building_library.gd 淹沒,不好找真正要調的數值欄位。key 是 GameEnums.BuildingType
## (Building.type 本身就是唯一識別碼,不另外維護一份字串 id,見 building.gd 開頭註解)。
##
## 取自 Scenes/Base/base_inner.tscn 裡每棟建築對應的 Polygon2D 節點(節點名稱就是
## GameEnums.BuildingType 的 enum 成員名稱,方便對照),使用者直接在編輯器內於
## Images/Base/base_<TERRAIN>.jpg(1024x559 原始像素尺寸)背景上手繪外框後轉錄進這裡。
## 這些 Polygon2D 節點刻意保留在場景裡當作日後重新校準的參考,不刪除——只是
## visible=false 隱藏,要重新調整範圍時在編輯器打開該節點的可見度即可直接看到疊在
## 背景上的舊外框。
##
## 這裡的座標不需要額外加任何位移:base_inner.gd 用 Node2D.scale(= 當下視窗大小 ÷
## 背景原始像素尺寸)整個節點等比縮放撐滿畫面,不是移動/裁切背景本身,所以
## Polygon2D 節點上直接畫出來的頂點座標,就是 territory_polygon 要存的原始像素座標,
## 跟 BaseSystem.pick_building() 用 get_local_mouse_position() 比對時吃的是同一個
## 座標系(Node2D.scale 是 Godot 內建座標轉換,點擊判定不需要另外換算)。不另外存
## 中心點座標,需要時呼叫 Building.center() 現算(見該函式)。

## 查不到 building_type 回傳空陣列——理論上不該發生(GameEnums.BuildingType 每個成員都要
## 在這裡有對應項目),空陣列讓 BaseSystem.pick_building() 自然判定「點不到」而不是炸掉。
static func get_polygon(building_type: GameEnums.BuildingType) -> PackedVector2Array:
	return _POLYGONS.get(building_type, PackedVector2Array())


## PackedVector2Array([...]) 是建構子呼叫,GDScript 的 const 只接受純常數表達式,
## 這裡改用 static var(類別載入時只初始化一次,語意上跟 const 一樣不會被外部改動,
## 呼叫端一律走 get_polygon() 不要直接碰這個字典)。
static var _POLYGONS: Dictionary = {
	GameEnums.BuildingType.STRONGHOLD: PackedVector2Array([
		Vector2(628, 154), Vector2(745, 220), Vector2(890, 146), Vector2(888, 86),
		Vector2(875, 67), Vector2(851, 91), Vector2(802, 65), Vector2(774, 15),
		Vector2(696, 45), Vector2(695, 82), Vector2(669, 98), Vector2(649, 68),
		Vector2(631, 98),
	]),
	GameEnums.BuildingType.RESIDENTIAL: PackedVector2Array([
		Vector2(618, 371), Vector2(730, 422), Vector2(812, 379), Vector2(831, 332),
		Vector2(862, 313), Vector2(864, 272), Vector2(846, 250), Vector2(816, 267),
		Vector2(781, 255), Vector2(750, 230), Vector2(699, 248), Vector2(636, 282),
		Vector2(611, 334),
	]),
	GameEnums.BuildingType.CLINIC: PackedVector2Array([
		Vector2(871, 370), Vector2(918, 400), Vector2(937, 387), Vector2(995, 419),
		Vector2(1096, 364), Vector2(1092, 353), Vector2(1059, 337), Vector2(1058, 308),
		Vector2(996, 281), Vector2(988, 262), Vector2(902, 311), Vector2(906, 335),
		Vector2(881, 341),
	]),
	GameEnums.BuildingType.WAREHOUSE: PackedVector2Array([
		Vector2(872, 216), Vector2(895, 231), Vector2(921, 227), Vector2(955, 261),
		Vector2(987, 257), Vector2(1044, 242), Vector2(1039, 225), Vector2(1076, 205),
		Vector2(1076, 181), Vector2(1063, 176), Vector2(1064, 150), Vector2(1048, 125),
		Vector2(1023, 140), Vector2(989, 125), Vector2(974, 136), Vector2(961, 115),
		Vector2(893, 151), Vector2(881, 165),
	]),
	GameEnums.BuildingType.BARRACKS: PackedVector2Array([
		Vector2(1056, 233), Vector2(1229, 323), Vector2(1380, 240), Vector2(1378, 227),
		Vector2(1204, 138), Vector2(1056, 218),
	]),
	GameEnums.BuildingType.FORGE: PackedVector2Array([
		Vector2(575, 642), Vector2(609, 661), Vector2(607, 677), Vector2(628, 681),
		Vector2(631, 669), Vector2(702, 693), Vector2(744, 673), Vector2(806, 650),
		Vector2(760, 621), Vector2(791, 606), Vector2(785, 554), Vector2(731, 516),
		Vector2(719, 505), Vector2(705, 517), Vector2(693, 547), Vector2(621, 575),
		Vector2(583, 600),
	]),
	GameEnums.BuildingType.LUMBER_MILL: PackedVector2Array([
		Vector2(999, 652), Vector2(1030, 655), Vector2(1055, 685), Vector2(1097, 687),
		Vector2(1194, 647), Vector2(1224, 657), Vector2(1254, 642), Vector2(1238, 613),
		Vector2(1214, 615), Vector2(1209, 592), Vector2(1185, 573), Vector2(1172, 546),
		Vector2(1130, 563), Vector2(1126, 543), Vector2(1087, 560), Vector2(1027, 593),
	]),
	GameEnums.BuildingType.QUARRY: PackedVector2Array([
		Vector2(1409, 285), Vector2(1408, 496), Vector2(1160, 480), Vector2(1126, 424),
		Vector2(1210, 367), Vector2(1305, 320), Vector2(1376, 287),
	]),
	GameEnums.BuildingType.FARM: PackedVector2Array([
		Vector2(313, 389), Vector2(414, 447), Vector2(425, 430), Vector2(446, 440),
		Vector2(446, 458), Vector2(478, 453), Vector2(499, 482), Vector2(536, 486),
		Vector2(583, 480), Vector2(600, 539), Vector2(412, 649), Vector2(243, 565),
		Vector2(288, 531), Vector2(245, 507), Vector2(303, 476), Vector2(229, 438),
	]),
	GameEnums.BuildingType.MINE: PackedVector2Array([
		Vector2(0, 434), Vector2(1, 482), Vector2(70, 510), Vector2(124, 502),
		Vector2(222, 518), Vector2(245, 466), Vector2(218, 437), Vector2(159, 388),
		Vector2(101, 357), Vector2(82, 360), Vector2(43, 399),
	]),
	GameEnums.BuildingType.CARAVAN: PackedVector2Array([
		Vector2(745, 503), Vector2(777, 423), Vector2(836, 407), Vector2(900, 419),
		Vector2(944, 448), Vector2(1000, 481), Vector2(987, 518), Vector2(917, 511),
		Vector2(821, 532),
	]),
	GameEnums.BuildingType.BLACK_MARKET: PackedVector2Array([
		Vector2(539, 355), Vector2(594, 379), Vector2(619, 413), Vector2(595, 446),
		Vector2(503, 458), Vector2(461, 440), Vector2(444, 407), Vector2(447, 377),
		Vector2(474, 358),
	]),
	GameEnums.BuildingType.HUNTING_GROUND: PackedVector2Array([
		Vector2(193, 589), Vector2(286, 614), Vector2(297, 666), Vector2(241, 737),
		Vector2(110, 732), Vector2(54, 683), Vector2(90, 635),
	]),
	GameEnums.BuildingType.WORKSHOP: PackedVector2Array([
		Vector2(526, 599), Vector2(534, 599), Vector2(540, 627), Vector2(550, 619),
		Vector2(567, 645), Vector2(586, 656), Vector2(601, 705), Vector2(569, 733),
		Vector2(519, 732), Vector2(459, 698), Vector2(471, 671), Vector2(474, 645),
		Vector2(527, 626),
	]),
	GameEnums.BuildingType.SCRIPTORIUM: PackedVector2Array([
		Vector2(470, 137), Vector2(549, 183), Vector2(545, 239), Vector2(511, 236),
		Vector2(477, 253), Vector2(419, 221), Vector2(423, 186), Vector2(454, 161),
	]),
	GameEnums.BuildingType.RESEARCH_INSTITUTE: PackedVector2Array([
		Vector2(235, 301), Vector2(349, 361), Vector2(471, 299), Vector2(363, 227),
		Vector2(355, 210), Vector2(295, 223), Vector2(274, 261),
	]),
	GameEnums.BuildingType.ALTAR: PackedVector2Array([
		Vector2(336, 159), Vector2(309, 167), Vector2(287, 157), Vector2(267, 167),
		Vector2(177, 120), Vector2(179, 110), Vector2(194, 103), Vector2(194, 75),
		Vector2(212, 60), Vector2(208, 37), Vector2(229, 21), Vector2(304, 56),
		Vector2(305, 65), Vector2(322, 67), Vector2(325, 97), Vector2(349, 111),
		Vector2(341, 129), Vector2(364, 112), Vector2(380, 131), Vector2(380, 151),
	]),
	GameEnums.BuildingType.FORBIDDEN_ALTAR: PackedVector2Array([
		Vector2(79, 200), Vector2(109, 223), Vector2(124, 255), Vector2(146, 271),
		Vector2(132, 301), Vector2(90, 310), Vector2(36, 282), Vector2(37, 233),
	]),
}
