class_name BuildingPositions
extends RefCounted

## 根據地建築的畫面座標資料——跟 BuildingLibrary 的遊戲數值(名稱/描述/耗材/產出等)
## 分開放,這裡只放「這棟建築在背景圖上的外框多邊形」,不然座標數字會把
## building_library.gd 淹沒,不好找真正要調的數值欄位。key 是 GameEnums.BuildingType
## (Building.type 本身就是唯一識別碼,不另外維護一份字串 id,見 building.gd 開頭註解)。
##
## 取自使用者在 Images/Base/base_with_text.jpg(1024x559)上,依建築圖示外框手繪的
## Polygon2D 頂點(原本暫存在 Scenes/Base/base.tscn 裡當參考,已經轉錄進這裡,不用兩邊
## 各存一份)。背景圖在 Scenes/Base/base.tscn 裡整體下移了 8.5(offset_top,置中對齊
## 1600x900 視窗的計算見該檔案節點註解),這裡的 Y 座標已經跟著加上同樣的位移,兩邊要
## 保持一致——背景之後再調位置,記得同步改這裡。不另外存中心點座標,需要時呼叫
## Building.center() 現算(見該函式)。

## 查不到 building_type 回傳空陣列——理論上不該發生(GameEnums.BuildingType 每個成員都要
## 在這裡有對應項目),空陣列讓 BaseSystem.pick_building() 自然判定「點不到」而不是炸掉。
static func get_polygon(building_type: GameEnums.BuildingType) -> PackedVector2Array:
	return _POLYGONS.get(building_type, PackedVector2Array())


## PackedVector2Array([...]) 是建構子呼叫,GDScript 的 const 只接受純常數表達式,
## 這裡改用 static var(類別載入時只初始化一次,語意上跟 const 一樣不會被外部改動,
## 呼叫端一律走 get_polygon() 不要直接碰這個字典)。
static var _POLYGONS: Dictionary = {
	GameEnums.BuildingType.STRONGHOLD: PackedVector2Array([
		Vector2(471.03998, 56.5), Vector2(460.8, 76.979996), Vector2(458.88, 118.579994), Vector2(548.48, 171.06),
		Vector2(648.95996, 115.38), Vector2(647.04, 68.02), Vector2(637.44, 53.3), Vector2(622.07996, 73.14),
		Vector2(581.12, 53.94), Vector2(572.16, 29.619999), Vector2(560, 12.98), Vector2(547.2, 33.46),
		Vector2(533.12, 25.779999), Vector2(526.08, 38.58), Vector2(515.83997, 42.42), Vector2(510.72, 33.46),
		Vector2(499.84, 68.66), Vector2(486.4, 73.78),
	]),
	GameEnums.BuildingType.RESIDENTIAL: PackedVector2Array([
		Vector2(467.84, 208.18), Vector2(503.03998, 188.34), Vector2(543.36, 175.54), Vector2(579.83997, 197.94),
		Vector2(617.6, 193.45999), Vector2(628.48, 213.94), Vector2(620.8, 247.22), Vector2(583.68, 295.22),
		Vector2(533.76, 316.97998), Vector2(451.19998, 277.3), Vector2(442.88, 244.01999),
	]),
	GameEnums.BuildingType.CLINIC: PackedVector2Array([
		Vector2(630.39996, 279.22), Vector2(663.04, 299.69998), Vector2(686.07996, 298.41998), Vector2(723.83997, 316.34),
		Vector2(800.63995, 271.54), Vector2(773.12, 249.14), Vector2(771.2, 226.73999), Vector2(711.68, 197.94),
		Vector2(636.8, 240.18), Vector2(629.12, 276.66),
	]),
	GameEnums.BuildingType.WAREHOUSE: PackedVector2Array([
		Vector2(697.6, 89.78), Vector2(650.24, 119.22), Vector2(639.36, 129.46), Vector2(636.8, 168.5),
		Vector2(659.83997, 183.86), Vector2(698.24, 197.3), Vector2(746.24, 186.42), Vector2(778.88, 156.34),
		Vector2(778.24, 139.06), Vector2(762.24, 96.82), Vector2(746.24, 109.619995), Vector2(721.27997, 101.299995),
		Vector2(711.68, 106.42),
	]),
	GameEnums.BuildingType.BARRACKS: PackedVector2Array([
		Vector2(892.8, 243.37999), Vector2(1006.07996, 183.22), Vector2(1006.72, 168.5), Vector2(875.51996, 106.42),
		Vector2(768, 167.86), Vector2(766.72, 179.37999),
	]),
	GameEnums.BuildingType.LUMBER_MILL: PackedVector2Array([
		Vector2(785.92, 411.06), Vector2(818.56, 404.02), Vector2(855.68, 405.3), Vector2(887.68, 444.34),
		Vector2(917.12, 468.66), Vector2(883.19995, 497.46), Vector2(856.95996, 485.3), Vector2(803.2, 519.86),
		Vector2(754.56, 512.81998), Vector2(721.27997, 487.86), Vector2(725.76, 448.18),
	]),
	GameEnums.BuildingType.QUARRY: PackedVector2Array([
		Vector2(860.8, 288.82), Vector2(913.27997, 262.58), Vector2(940.8, 250.42), Vector2(1009.27997, 214.58),
		Vector2(1025.28, 213.94), Vector2(1023.36, 373.94), Vector2(947.83997, 379.69998), Vector2(847.36, 363.06),
		Vector2(823.68, 348.97998), Vector2(819.19995, 316.97998),
	]),
	GameEnums.BuildingType.FARM: PackedVector2Array([
		Vector2(170.87999, 324.66), Vector2(222.08, 293.3), Vector2(304.63998, 333.62), Vector2(307.19998, 320.82),
		Vector2(322.56, 325.94), Vector2(325.12, 340.66), Vector2(348.8, 337.46), Vector2(364.16, 361.78),
		Vector2(393.6, 359.22), Vector2(424.96, 359.22), Vector2(416.63998, 380.34), Vector2(439.68, 398.9),
		Vector2(288.63998, 480.81998), Vector2(172.16, 421.94), Vector2(206.08, 397.62), Vector2(176.64, 380.34),
		Vector2(215.04, 354.74),
	]),
	GameEnums.BuildingType.MINE: PackedVector2Array([
		Vector2(63.359997, 263.86), Vector2(110.72, 283.69998), Vector2(160, 325.94), Vector2(180.48, 347.69998),
		Vector2(169.59999, 372.66), Vector2(160.64, 385.46), Vector2(105.6, 368.81998), Vector2(71.68, 384.81998),
		Vector2(23.68, 377.13998), Vector2(-0.64, 360.5), Vector2(0.64, 317.62),
	]),
	GameEnums.BuildingType.CARAVAN: PackedVector2Array([
		Vector2(596.48, 306.74), Vector2(641.92, 304.18), Vector2(673.92, 321.46), Vector2(696.32, 340.02),
		Vector2(728.95996, 353.46), Vector2(714.24, 384.81998), Vector2(660.48, 380.97998), Vector2(618.24, 395.69998),
		Vector2(543.36, 383.53998), Vector2(538.24, 357.3), Vector2(570.88, 310.58),
	]),
	GameEnums.BuildingType.BLACK_MARKET: PackedVector2Array([
		Vector2(333.44, 321.46), Vector2(353.91998, 336.82), Vector2(428.16, 331.69998), Vector2(454.4, 316.97998),
		Vector2(432, 288.82), Vector2(390.4, 267.06), Vector2(359.03998, 265.78), Vector2(330.24, 283.06),
		Vector2(323.84, 303.54),
	]),
	GameEnums.BuildingType.HUNTING_GROUND: PackedVector2Array([
		Vector2(138.87999, 432.18), Vector2(206.08, 448.81998), Vector2(211.84, 489.13998), Vector2(174.72, 544.18),
		Vector2(101.759995, 545.45996), Vector2(44.8, 522.42), Vector2(49.28, 460.97998),
	]),
	GameEnums.BuildingType.WORKSHOP: PackedVector2Array([
		Vector2(342.4, 484.02), Vector2(380.8, 463.53998), Vector2(381.44, 443.69998), Vector2(392.96, 443.69998),
		Vector2(392.96, 463.53998), Vector2(450.56, 418.74), Vector2(483.19998, 419.38), Vector2(533.12, 436.66),
		Vector2(582.39996, 479.53998), Vector2(405.12, 547.38), Vector2(328.32, 517.94),
	]),
	GameEnums.BuildingType.SCRIPTORIUM: PackedVector2Array([
		Vector2(305.28, 128.18), Vector2(303.36, 174.9), Vector2(344.96, 196.01999), Vector2(366.72, 184.5),
		Vector2(399.36, 186.42), Vector2(417.28, 158.9), Vector2(386.56, 130.1), Vector2(336.63998, 103.86),
		Vector2(328.96, 124.979996),
	]),
	GameEnums.BuildingType.RESEARCH_INSTITUTE: PackedVector2Array([
		Vector2(163.2, 224.81999), Vector2(254.72, 271.54), Vector2(339.84, 223.54), Vector2(254.72, 160.81999),
		Vector2(218.23999, 167.86),
	]),
	GameEnums.BuildingType.ALTAR: PackedVector2Array([
		Vector2(209.28, 124.34), Vector2(180.48, 126.259995), Vector2(133.12, 92.979996), Vector2(140.16, 62.26),
		Vector2(160.64, 16.18), Vector2(197.12, 32.18), Vector2(234.87999, 56.5), Vector2(256, 89.14),
		Vector2(250.87999, 121.78),
	]),
	# 原始 Polygon2D 節點有 position = Vector2(8.32, -7.68) 位移,這裡直接把位移加進
	# 每個頂點,存成跟其他建築一致的「絕對座標」多邊形;背景圖整體下移 8.5(見上面
	# 其他建築的 Y 座標)後,這份位移沒有變,一樣疊在最終座標上。
	GameEnums.BuildingType.FORBIDDEN_ALTAR: PackedVector2Array([
		Vector2(74.24, 241.45998), Vector2(-1.279999, 243.37998), Vector2(0, 125.619995), Vector2(85.119995, 128.82),
		Vector2(113.92, 148.66), Vector2(158.72, 208.17999),
	]),
}
