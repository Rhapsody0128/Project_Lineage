class_name BuildingPositions
extends RefCounted

## 根據地建築的畫面座標資料——跟 BuildingLibrary 的遊戲數值(名稱/描述/耗材/產出等)
## 分開放,這裡只放「這棟建築在背景圖上的外框多邊形」,不然座標數字會把
## building_library.gd 淹沒,不好找真正要調的數值欄位。key 是 GameEnums.BuildingType
## (Building.type 本身就是唯一識別碼,不另外維護一份字串 id,見 building.gd 開頭註解)。
##
## 取自使用者在 Images/Base/base_with_text.jpg(1024x559)上,依建築圖示外框手繪的
## Polygon2D 頂點(原本暫存在 Scenes/Base/base.tscn 裡當參考,已經轉錄進這裡,不用兩邊
## 各存一份)。背景圖在 Scenes/Base/base.tscn 裡整體下移了 25.6(offset_top),這裡的 Y
## 座標已經跟著加上同樣的位移,兩邊要保持一致——背景之後再調位置,記得同步改這裡。不
## 另外存中心點座標,需要時呼叫 Building.center() 現算(見該函式)。

## 查不到 building_type 回傳空陣列——理論上不該發生(GameEnums.BuildingType 每個成員都要
## 在這裡有對應項目),空陣列讓 BaseSystem.pick_building() 自然判定「點不到」而不是炸掉。
static func get_polygon(building_type: GameEnums.BuildingType) -> PackedVector2Array:
	return _POLYGONS.get(building_type, PackedVector2Array())


## PackedVector2Array([...]) 是建構子呼叫,GDScript 的 const 只接受純常數表達式,
## 這裡改用 static var(類別載入時只初始化一次,語意上跟 const 一樣不會被外部改動,
## 呼叫端一律走 get_polygon() 不要直接碰這個字典)。
static var _POLYGONS: Dictionary = {
	GameEnums.BuildingType.STRONGHOLD: PackedVector2Array([
		Vector2(471.03998, 73.6), Vector2(460.8, 94.079996), Vector2(458.88, 135.679994), Vector2(548.48, 188.16),
		Vector2(648.95996, 132.48), Vector2(647.04, 85.12), Vector2(637.44, 70.4), Vector2(622.07996, 90.24),
		Vector2(581.12, 71.04), Vector2(572.16, 46.719999), Vector2(560, 30.08), Vector2(547.2, 50.56),
		Vector2(533.12, 42.879999), Vector2(526.08, 55.68), Vector2(515.83997, 59.52), Vector2(510.72, 50.56),
		Vector2(499.84, 85.76), Vector2(486.4, 90.88),
	]),
	GameEnums.BuildingType.RESIDENTIAL: PackedVector2Array([
		Vector2(467.84, 225.28), Vector2(503.03998, 205.44), Vector2(543.36, 192.64), Vector2(579.83997, 215.04),
		Vector2(617.6, 210.55999), Vector2(628.48, 231.04), Vector2(620.8, 264.32), Vector2(583.68, 312.32),
		Vector2(533.76, 334.07998), Vector2(451.19998, 294.4), Vector2(442.88, 261.11999),
	]),
	GameEnums.BuildingType.CLINIC: PackedVector2Array([
		Vector2(630.39996, 296.32), Vector2(663.04, 316.79998), Vector2(686.07996, 315.51998), Vector2(723.83997, 333.44),
		Vector2(800.63995, 288.64), Vector2(773.12, 266.24), Vector2(771.2, 243.83999), Vector2(711.68, 215.04),
		Vector2(636.8, 257.28), Vector2(629.12, 293.76),
	]),
	GameEnums.BuildingType.WAREHOUSE: PackedVector2Array([
		Vector2(697.6, 106.88), Vector2(650.24, 136.32), Vector2(639.36, 146.56), Vector2(636.8, 185.6),
		Vector2(659.83997, 200.96), Vector2(698.24, 214.4), Vector2(746.24, 203.52), Vector2(778.88, 173.44),
		Vector2(778.24, 156.16), Vector2(762.24, 113.92), Vector2(746.24, 126.719995), Vector2(721.27997, 118.399995),
		Vector2(711.68, 123.52),
	]),
	GameEnums.BuildingType.BARRACKS: PackedVector2Array([
		Vector2(892.8, 260.47999), Vector2(1006.07996, 200.32), Vector2(1006.72, 185.6), Vector2(875.51996, 123.52),
		Vector2(768, 184.96), Vector2(766.72, 196.47999),
	]),
	GameEnums.BuildingType.LUMBER_MILL: PackedVector2Array([
		Vector2(785.92, 428.16), Vector2(818.56, 421.12), Vector2(855.68, 422.4), Vector2(887.68, 461.44),
		Vector2(917.12, 485.76), Vector2(883.19995, 514.56), Vector2(856.95996, 502.4), Vector2(803.2, 536.96),
		Vector2(754.56, 529.91998), Vector2(721.27997, 504.96), Vector2(725.76, 465.28),
	]),
	GameEnums.BuildingType.QUARRY: PackedVector2Array([
		Vector2(860.8, 305.92), Vector2(913.27997, 279.68), Vector2(940.8, 267.52), Vector2(1009.27997, 231.68),
		Vector2(1025.28, 231.04), Vector2(1023.36, 391.04), Vector2(947.83997, 396.79998), Vector2(847.36, 380.16),
		Vector2(823.68, 366.07998), Vector2(819.19995, 334.07998),
	]),
	GameEnums.BuildingType.FARM: PackedVector2Array([
		Vector2(170.87999, 341.76), Vector2(222.08, 310.4), Vector2(304.63998, 350.72), Vector2(307.19998, 337.92),
		Vector2(322.56, 343.04), Vector2(325.12, 357.76), Vector2(348.8, 354.56), Vector2(364.16, 378.88),
		Vector2(393.6, 376.32), Vector2(424.96, 376.32), Vector2(416.63998, 397.44), Vector2(439.68, 416),
		Vector2(288.63998, 497.91998), Vector2(172.16, 439.04), Vector2(206.08, 414.72), Vector2(176.64, 397.44),
		Vector2(215.04, 371.84),
	]),
	GameEnums.BuildingType.MINE: PackedVector2Array([
		Vector2(63.359997, 280.96), Vector2(110.72, 300.79998), Vector2(160, 343.04), Vector2(180.48, 364.79998),
		Vector2(169.59999, 389.76), Vector2(160.64, 402.56), Vector2(105.6, 385.91998), Vector2(71.68, 401.91998),
		Vector2(23.68, 394.23998), Vector2(-0.64, 377.6), Vector2(0.64, 334.72),
	]),
	GameEnums.BuildingType.CARAVAN: PackedVector2Array([
		Vector2(596.48, 323.84), Vector2(641.92, 321.28), Vector2(673.92, 338.56), Vector2(696.32, 357.12),
		Vector2(728.95996, 370.56), Vector2(714.24, 401.91998), Vector2(660.48, 398.07998), Vector2(618.24, 412.79998),
		Vector2(543.36, 400.63998), Vector2(538.24, 374.4), Vector2(570.88, 327.68),
	]),
	GameEnums.BuildingType.BLACK_MARKET: PackedVector2Array([
		Vector2(333.44, 338.56), Vector2(353.91998, 353.92), Vector2(428.16, 348.79998), Vector2(454.4, 334.07998),
		Vector2(432, 305.92), Vector2(390.4, 284.16), Vector2(359.03998, 282.88), Vector2(330.24, 300.16),
		Vector2(323.84, 320.64),
	]),
	GameEnums.BuildingType.HUNTING_GROUND: PackedVector2Array([
		Vector2(138.87999, 449.28), Vector2(206.08, 465.91998), Vector2(211.84, 506.23998), Vector2(174.72, 561.28),
		Vector2(101.759995, 562.55996), Vector2(44.8, 539.52), Vector2(49.28, 478.07998),
	]),
	GameEnums.BuildingType.WORKSHOP: PackedVector2Array([
		Vector2(342.4, 501.12), Vector2(380.8, 480.63998), Vector2(381.44, 460.79998), Vector2(392.96, 460.79998),
		Vector2(392.96, 480.63998), Vector2(450.56, 435.84), Vector2(483.19998, 436.48), Vector2(533.12, 453.76),
		Vector2(582.39996, 496.63998), Vector2(405.12, 564.48), Vector2(328.32, 535.04),
	]),
	GameEnums.BuildingType.SCRIPTORIUM: PackedVector2Array([
		Vector2(305.28, 145.28), Vector2(303.36, 192), Vector2(344.96, 213.11999), Vector2(366.72, 201.6),
		Vector2(399.36, 203.52), Vector2(417.28, 176), Vector2(386.56, 147.2), Vector2(336.63998, 120.96),
		Vector2(328.96, 142.079996),
	]),
	GameEnums.BuildingType.RESEARCH_INSTITUTE: PackedVector2Array([
		Vector2(163.2, 241.91999), Vector2(254.72, 288.64), Vector2(339.84, 240.64), Vector2(254.72, 177.91999),
		Vector2(218.23999, 184.96),
	]),
	GameEnums.BuildingType.ALTAR: PackedVector2Array([
		Vector2(209.28, 141.44), Vector2(180.48, 143.359995), Vector2(133.12, 110.079996), Vector2(140.16, 79.36),
		Vector2(160.64, 33.28), Vector2(197.12, 49.28), Vector2(234.87999, 73.6), Vector2(256, 106.24),
		Vector2(250.87999, 138.88),
	]),
	# 原始 Polygon2D 節點有 position = Vector2(8.32, -7.68) 位移,這裡直接把位移加進
	# 每個頂點,存成跟其他建築一致的「絕對座標」多邊形;背景圖整體下移 25.6(見上面
	# 其他建築的 Y 座標)後,這份位移沒有變,一樣疊在最終座標上。
	GameEnums.BuildingType.FORBIDDEN_ALTAR: PackedVector2Array([
		Vector2(74.24, 258.55998), Vector2(-1.279999, 260.47998), Vector2(0.0, 142.719995), Vector2(85.119995, 145.92),
		Vector2(113.92, 165.76), Vector2(158.72, 225.27999),
	]),
}
