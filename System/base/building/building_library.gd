class_name BuildingLibrary
extends RefCounted

## 根據地全部 17 種建築的集中定義(遊戲企劃設定總整理.md 六十八節)。territory_polygon
## 取自使用者在 Images/Base/base_with_text.jpg(1024x559)上,依建築圖示外框手繪的
## Polygon2D 頂點(原本暫存在 Scenes/Base/base.tscn 裡當參考,已經轉錄進這裡,不用兩邊
## 各存一份)。不另外存中心點座標,需要時呼叫 Building.center() 現算(見該函式)。
## 背景圖在 Scenes/Base/base.tscn 裡整體下移了 25.6(offset_top),這裡的 Y 座標已經
## 跟著加上同樣的位移,兩邊要保持一致——背景之後再調位置,記得同步改這裡。
##
## 每棟建築的 upgrade_costs 由 _scaled_costs() 依各自的 base 耗材 dict 展開成 9 級陣列
## (見該函式註解),數字只是先求有、方便先跑通整套升級流程的佔位值,之後要平衡難度
## 直接改這裡每棟建築傳入的 base dict 即可,不影響其他建築。

## 依「基礎耗材 * 目標等級」線性展開成 levels 級的升級耗材表,index i = 從第 i 級升到
## 第 i+1 級所需資源(即目標等級 i+1 的耗材 = base * (i+1))。目前全部建築統一 9 級,
## 對應 GameEnums.RankType 的 F~SSS。
static func _scaled_costs(base: Dictionary, levels: int = 9) -> Array[Dictionary]:
	var costs: Array[Dictionary] = []
	for level in range(1, levels + 1):
		var scaled: Dictionary = {}
		for resource_type in base:
			scaled[resource_type] = base[resource_type] * level
		costs.append(scaled)
	return costs


static func get_all() -> Array[Building]:
	return [
		Building.new("MainCity", "大本營", GameEnums.BuildingType.STRONGHOLD, -1, -1, 0, {}, PackedVector2Array([
			Vector2(471.03998, 73.6), Vector2(460.8, 94.079996), Vector2(458.88, 135.679994), Vector2(548.48, 188.16),
			Vector2(648.95996, 132.48), Vector2(647.04, 85.12), Vector2(637.44, 70.4), Vector2(622.07996, 90.24),
			Vector2(581.12, 71.04), Vector2(572.16, 46.719999), Vector2(560, 30.08), Vector2(547.2, 50.56),
			Vector2(533.12, 42.879999), Vector2(526.08, 55.68), Vector2(515.83997, 59.52), Vector2(510.72, 50.56),
			Vector2(499.84, 85.76), Vector2(486.4, 90.88),
		]), _scaled_costs({GameEnums.ResourceType.WOOD: 30, GameEnums.ResourceType.STONE: 30})),
		Building.new("ResidentialDistrict", "住宅區", GameEnums.BuildingType.RESIDENTIAL, -1, -1, 0, {}, PackedVector2Array([
			Vector2(467.84, 225.28), Vector2(503.03998, 205.44), Vector2(543.36, 192.64), Vector2(579.83997, 215.04),
			Vector2(617.6, 210.55999), Vector2(628.48, 231.04), Vector2(620.8, 264.32), Vector2(583.68, 312.32),
			Vector2(533.76, 334.07998), Vector2(451.19998, 294.4), Vector2(442.88, 261.11999),
		]), _scaled_costs({GameEnums.ResourceType.WOOD: 20, GameEnums.ResourceType.STONE: 10})),
		Building.new("Medicalcenter", "醫療所", GameEnums.BuildingType.CLINIC, -1, -1, 0, {}, PackedVector2Array([
			Vector2(630.39996, 296.32), Vector2(663.04, 316.79998), Vector2(686.07996, 315.51998), Vector2(723.83997, 333.44),
			Vector2(800.63995, 288.64), Vector2(773.12, 266.24), Vector2(771.2, 243.83999), Vector2(711.68, 215.04),
			Vector2(636.8, 257.28), Vector2(629.12, 293.76),
		]), _scaled_costs({GameEnums.ResourceType.WOOD: 10, GameEnums.ResourceType.STONE: 20})),
		Building.new("warehouse", "倉庫", GameEnums.BuildingType.WAREHOUSE, -1, -1, 0, {}, PackedVector2Array([
			Vector2(697.6, 106.88), Vector2(650.24, 136.32), Vector2(639.36, 146.56), Vector2(636.8, 185.6),
			Vector2(659.83997, 200.96), Vector2(698.24, 214.4), Vector2(746.24, 203.52), Vector2(778.88, 173.44),
			Vector2(778.24, 156.16), Vector2(762.24, 113.92), Vector2(746.24, 126.719995), Vector2(721.27997, 118.399995),
			Vector2(711.68, 123.52),
		]), _scaled_costs({GameEnums.ResourceType.WOOD: 20, GameEnums.ResourceType.STONE: 20})),
		Building.new("barrack", "兵營", GameEnums.BuildingType.BARRACKS, -1, -1, 0, {}, PackedVector2Array([
			Vector2(892.8, 260.47999), Vector2(1006.07996, 200.32), Vector2(1006.72, 185.6), Vector2(875.51996, 123.52),
			Vector2(768, 184.96), Vector2(766.72, 196.47999),
		]), _scaled_costs({GameEnums.ResourceType.WOOD: 15, GameEnums.ResourceType.STONE: 15, GameEnums.ResourceType.ORE: 10})),
		Building.new("Lumber mill", "伐木場", GameEnums.BuildingType.LUMBER_MILL, GameEnums.PotentialType.STRENGTH, GameEnums.ResourceType.WOOD, 5, {}, PackedVector2Array([
			Vector2(785.92, 428.16), Vector2(818.56, 421.12), Vector2(855.68, 422.4), Vector2(887.68, 461.44),
			Vector2(917.12, 485.76), Vector2(883.19995, 514.56), Vector2(856.95996, 502.4), Vector2(803.2, 536.96),
			Vector2(754.56, 529.91998), Vector2(721.27997, 504.96), Vector2(725.76, 465.28),
		]), _scaled_costs({GameEnums.ResourceType.WOOD: 10, GameEnums.ResourceType.STONE: 5})),
		Building.new("quarry", "採石場", GameEnums.BuildingType.QUARRY, GameEnums.PotentialType.STRENGTH, GameEnums.ResourceType.STONE, 3, {}, PackedVector2Array([
			Vector2(860.8, 305.92), Vector2(913.27997, 279.68), Vector2(940.8, 267.52), Vector2(1009.27997, 231.68),
			Vector2(1025.28, 231.04), Vector2(1023.36, 391.04), Vector2(947.83997, 396.79998), Vector2(847.36, 380.16),
			Vector2(823.68, 366.07998), Vector2(819.19995, 334.07998),
		]), _scaled_costs({GameEnums.ResourceType.STONE: 15, GameEnums.ResourceType.ORE: 5})),
		Building.new("Farm", "農田", GameEnums.BuildingType.FARM, GameEnums.PotentialType.VITALITY, GameEnums.ResourceType.FOOD, 5, {}, PackedVector2Array([
			Vector2(170.87999, 341.76), Vector2(222.08, 310.4), Vector2(304.63998, 350.72), Vector2(307.19998, 337.92),
			Vector2(322.56, 343.04), Vector2(325.12, 357.76), Vector2(348.8, 354.56), Vector2(364.16, 378.88),
			Vector2(393.6, 376.32), Vector2(424.96, 376.32), Vector2(416.63998, 397.44), Vector2(439.68, 416),
			Vector2(288.63998, 497.91998), Vector2(172.16, 439.04), Vector2(206.08, 414.72), Vector2(176.64, 397.44),
			Vector2(215.04, 371.84),
		]), _scaled_costs({GameEnums.ResourceType.WOOD: 8, GameEnums.ResourceType.FOOD: 5})),
		Building.new("mine", "採礦場", GameEnums.BuildingType.MINE, GameEnums.PotentialType.VITALITY, GameEnums.ResourceType.ORE, 3, {}, PackedVector2Array([
			Vector2(63.359997, 280.96), Vector2(110.72, 300.79998), Vector2(160, 343.04), Vector2(180.48, 364.79998),
			Vector2(169.59999, 389.76), Vector2(160.64, 402.56), Vector2(105.6, 385.91998), Vector2(71.68, 401.91998),
			Vector2(23.68, 394.23998), Vector2(-0.64, 377.6), Vector2(0.64, 334.72),
		]), _scaled_costs({GameEnums.ResourceType.STONE: 15, GameEnums.ResourceType.ORE: 10})),
		Building.new("CaravanStation", "商隊站", GameEnums.BuildingType.CARAVAN, GameEnums.PotentialType.AGILITY, GameEnums.ResourceType.GOLD, 5, {}, PackedVector2Array([
			Vector2(596.48, 323.84), Vector2(641.92, 321.28), Vector2(673.92, 338.56), Vector2(696.32, 357.12),
			Vector2(728.95996, 370.56), Vector2(714.24, 401.91998), Vector2(660.48, 398.07998), Vector2(618.24, 412.79998),
			Vector2(543.36, 400.63998), Vector2(538.24, 374.4), Vector2(570.88, 327.68),
		]), _scaled_costs({GameEnums.ResourceType.WOOD: 10, GameEnums.ResourceType.GOLD: 5})),
		Building.new("BlackMarket", "黑市", GameEnums.BuildingType.BLACK_MARKET, GameEnums.PotentialType.AGILITY, GameEnums.ResourceType.CONTRABAND, 3, {}, PackedVector2Array([
			Vector2(333.44, 338.56), Vector2(353.91998, 353.92), Vector2(428.16, 348.79998), Vector2(454.4, 334.07998),
			Vector2(432, 305.92), Vector2(390.4, 284.16), Vector2(359.03998, 282.88), Vector2(330.24, 300.16),
			Vector2(323.84, 320.64),
		]), _scaled_costs({GameEnums.ResourceType.GOLD: 15, GameEnums.ResourceType.CONTRABAND: 5})),
		Building.new("Hunting Ground", "狩獵場", GameEnums.BuildingType.HUNTING_GROUND, GameEnums.PotentialType.DEXTERITY, GameEnums.ResourceType.FUR, 5, {}, PackedVector2Array([
			Vector2(138.87999, 449.28), Vector2(206.08, 465.91998), Vector2(211.84, 506.23998), Vector2(174.72, 561.28),
			Vector2(101.759995, 562.55996), Vector2(44.8, 539.52), Vector2(49.28, 478.07998),
		]), _scaled_costs({GameEnums.ResourceType.WOOD: 10, GameEnums.ResourceType.FUR: 5})),
		Building.new("Workshop", "工匠坊", GameEnums.BuildingType.WORKSHOP, GameEnums.PotentialType.DEXTERITY, GameEnums.ResourceType.CRAFT, 3, {
			GameEnums.ResourceType.WOOD: 2,
			GameEnums.ResourceType.STONE: 2,
			GameEnums.ResourceType.ORE: 1,
			GameEnums.ResourceType.FUR: 1,
		}, PackedVector2Array([
			Vector2(342.4, 501.12), Vector2(380.8, 480.63998), Vector2(381.44, 460.79998), Vector2(392.96, 460.79998),
			Vector2(392.96, 480.63998), Vector2(450.56, 435.84), Vector2(483.19998, 436.48), Vector2(533.12, 453.76),
			Vector2(582.39996, 496.63998), Vector2(405.12, 564.48), Vector2(328.32, 535.04),
		]), _scaled_costs({
			GameEnums.ResourceType.WOOD: 5, GameEnums.ResourceType.STONE: 5,
			GameEnums.ResourceType.ORE: 5, GameEnums.ResourceType.FUR: 5,
		})),
		Building.new("scribes' hall", "抄書院", GameEnums.BuildingType.SCRIPTORIUM, GameEnums.PotentialType.INTELLIGENCE, GameEnums.ResourceType.BOOK, 5, {}, PackedVector2Array([
			Vector2(305.28, 145.28), Vector2(303.36, 192), Vector2(344.96, 213.11999), Vector2(366.72, 201.6),
			Vector2(399.36, 203.52), Vector2(417.28, 176), Vector2(386.56, 147.2), Vector2(336.63998, 120.96),
			Vector2(328.96, 142.079996),
		]), _scaled_costs({GameEnums.ResourceType.WOOD: 10, GameEnums.ResourceType.BOOK: 5})),
		Building.new("science research institute", "科學研究所", GameEnums.BuildingType.RESEARCH_INSTITUTE, GameEnums.PotentialType.INTELLIGENCE, GameEnums.ResourceType.RESEARCH, 3, {
			GameEnums.ResourceType.BOOK: 2,
		}, PackedVector2Array([
			Vector2(163.2, 241.91999), Vector2(254.72, 288.64), Vector2(339.84, 240.64), Vector2(254.72, 177.91999),
			Vector2(218.23999, 184.96),
		]), _scaled_costs({GameEnums.ResourceType.BOOK: 10, GameEnums.ResourceType.RESEARCH: 5})),
		Building.new("altar", "祭壇", GameEnums.BuildingType.ALTAR, GameEnums.PotentialType.MENTALITY, GameEnums.ResourceType.FAITH, 5, {}, PackedVector2Array([
			Vector2(209.28, 141.44), Vector2(180.48, 143.359995), Vector2(133.12, 110.079996), Vector2(140.16, 79.36),
			Vector2(160.64, 33.28), Vector2(197.12, 49.28), Vector2(234.87999, 73.6), Vector2(256, 106.24),
			Vector2(250.87999, 138.88),
		]), _scaled_costs({GameEnums.ResourceType.STONE: 10, GameEnums.ResourceType.FAITH: 5})),
		Building.new("forbidden altar", "禁忌祭壇", GameEnums.BuildingType.FORBIDDEN_ALTAR, GameEnums.PotentialType.MENTALITY, GameEnums.ResourceType.CURSE, 3, {
			GameEnums.ResourceType.FAITH: 2,
		}, PackedVector2Array([
			# 原始 Polygon2D 節點有 position = Vector2(8.32, -7.68) 位移,這裡直接把位移
			# 加進每個頂點,存成跟其他建築一致的「絕對座標」多邊形;背景圖整體下移
			# 25.6(見下方 Y 座標)後,這份位移沒有變,一樣疊在最終座標上。
			Vector2(74.24, 258.55998), Vector2(-1.279999, 260.47998), Vector2(0.0, 142.719995), Vector2(85.119995, 145.92),
			Vector2(113.92, 165.76), Vector2(158.72, 225.27999),
		]), _scaled_costs({GameEnums.ResourceType.FAITH: 10, GameEnums.ResourceType.CURSE: 5})),
	]
