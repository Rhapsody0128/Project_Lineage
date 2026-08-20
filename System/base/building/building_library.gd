class_name BuildingLibrary
extends RefCounted

## 根據地全部 17 種建築的集中定義(遊戲企劃設定總整理.md 六十八節)。這裡只放遊戲數值
## (名稱/描述/素質需求/產出/耗材/天數),畫面座標(territory_polygon)分開放在
## System/base/building/building_positions.gd,由 Building._init() 依 type 自動查出
## (見 building.gd),這裡不用傳、也不用維護額外的字串 id——type 本身就是識別碼。
##
## 每個 Building.new() 呼叫一個參數一行,後面用註解標明對應 Building._init() 的哪個
## 欄位(順序見 building.gd),方便掃視/調整個別數值,不用回頭數第幾個參數。
##
## 只有伐木場(LUMBER_MILL)這輪手動設計了真正的建造/升級耗材+天數數字,作為之後其他
## 建築調整的參考基準;其餘 16 棟建築的 build_cost/upgrade_costs/upgrade_days 都是靠
## _scaled_costs()/_scaled_days() 展開的佔位值(build_days 統一佔位 2 天),之後要平衡
## 難度直接改該建築傳入的 base dict/天數即可,不影響其他建築。

## 依「基礎耗材 * 目標等級」線性展開成 levels 筆的升級耗材表,index i = 從第 i+1 級升到
## 第 i+2 級所需資源(即該級耗材 = base * (i+1))。目前全部建築統一 8 筆(1→2...8→9,
## 加上建造的 0→1 共 9 級,對應 GameEnums.RankType 的 F~SSS)。
static func _scaled_costs(base: Dictionary, levels: int = 8) -> Array[Dictionary]:
	var costs: Array[Dictionary] = []
	for level in range(1, levels + 1):
		var scaled: Dictionary = {}
		for resource_type in base:
			scaled[resource_type] = base[resource_type] * level
		costs.append(scaled)
	return costs


## 跟 _scaled_costs() 平行的天數表:index i = 從第 i+1 級升到第 i+2 級要花 base_days *
## (i+1) 天。
static func _scaled_days(base_days: int, levels: int = 8) -> Array[int]:
	var days: Array[int] = []
	for level in range(1, levels + 1):
		days.append(base_days * level)
	return days


static func get_all() -> Array[Building]:
	return [
		Building.new(
			GameEnums.BuildingType.STRONGHOLD,               ## 建築類型(同時也是識別碼)
			"大本營",                                        ## 中文名稱
			"根據地核心,決定建築等級上限與人口容量。",              ## ACTION PANEL 描述文字
			-1,                                              ## 素質需求(-1 = 非生產類建築)
			-1,                                              ## 產出資源(-1 = 無產出)
			0,                                               ## 基礎產量
			{},                                              ## 每次結算消耗資源
			{GameEnums.ResourceType.WOOD: 30, GameEnums.ResourceType.STONE: 30}, ## 建造(0→1)耗材
			2,                                               ## 建造天數
			_scaled_costs({GameEnums.ResourceType.WOOD: 30, GameEnums.ResourceType.STONE: 30}), ## 升級(1→9)耗材表
			_scaled_days(2)                                 ## 升級天數表
		),
		Building.new(
			GameEnums.BuildingType.RESIDENTIAL,               ## 建築類型(同時也是識別碼)
			"住宅區",                                         ## 中文名稱
			"增加根據地可容納的角色數量。",                        ## ACTION PANEL 描述文字
			-1,                                               ## 素質需求(-1 = 非生產類建築)
			-1,                                               ## 產出資源(-1 = 無產出)
			0,                                                ## 基礎產量
			{},                                               ## 每次結算消耗資源
			{GameEnums.ResourceType.WOOD: 20, GameEnums.ResourceType.STONE: 10}, ## 建造(0→1)耗材
			2,                                                ## 建造天數
			_scaled_costs({GameEnums.ResourceType.WOOD: 20, GameEnums.ResourceType.STONE: 10}), ## 升級(1→9)耗材表
			_scaled_days(2)                                  ## 升級天數表
		),
		Building.new(
			GameEnums.BuildingType.CLINIC,                    ## 建築類型(同時也是識別碼)
			"醫療所",                                         ## 中文名稱
			"治療傷兵,加速角色恢復。",                            ## ACTION PANEL 描述文字
			-1,                                               ## 素質需求(-1 = 非生產類建築)
			-1,                                               ## 產出資源(-1 = 無產出)
			0,                                                ## 基礎產量
			{},                                               ## 每次結算消耗資源
			{GameEnums.ResourceType.WOOD: 10, GameEnums.ResourceType.STONE: 20}, ## 建造(0→1)耗材
			2,                                                ## 建造天數
			_scaled_costs({GameEnums.ResourceType.WOOD: 10, GameEnums.ResourceType.STONE: 20}), ## 升級(1→9)耗材表
			_scaled_days(2)                                  ## 升級天數表
		),
		Building.new(
			GameEnums.BuildingType.WAREHOUSE,                 ## 建築類型(同時也是識別碼)
			"倉庫",                                           ## 中文名稱
			"增加各種資源的儲存上限。",                            ## ACTION PANEL 描述文字
			-1,                                               ## 素質需求(-1 = 非生產類建築)
			-1,                                               ## 產出資源(-1 = 無產出)
			0,                                                ## 基礎產量
			{},                                               ## 每次結算消耗資源
			{GameEnums.ResourceType.WOOD: 20, GameEnums.ResourceType.STONE: 20}, ## 建造(0→1)耗材
			2,                                                ## 建造天數
			_scaled_costs({GameEnums.ResourceType.WOOD: 20, GameEnums.ResourceType.STONE: 20}), ## 升級(1→9)耗材表
			_scaled_days(2)                                  ## 升級天數表
		),
		Building.new(
			GameEnums.BuildingType.BARRACKS,                  ## 建築類型(同時也是識別碼)
			"兵營",                                           ## 中文名稱
			"軍隊相關功能與訓練。",                               ## ACTION PANEL 描述文字
			-1,                                               ## 素質需求(-1 = 非生產類建築)
			-1,                                               ## 產出資源(-1 = 無產出)
			0,                                                ## 基礎產量
			{},                                               ## 每次結算消耗資源
			{GameEnums.ResourceType.WOOD: 15, GameEnums.ResourceType.STONE: 15, GameEnums.ResourceType.ORE: 10}, ## 建造(0→1)耗材
			2,                                                ## 建造天數
			_scaled_costs({GameEnums.ResourceType.WOOD: 15, GameEnums.ResourceType.STONE: 15, GameEnums.ResourceType.ORE: 10}), ## 升級(1→9)耗材表
			_scaled_days(2)                                  ## 升級天數表
		),
		# 伐木場是這輪唯一手動對標的建築,耗材/天數隨等級遞增的曲線是接下來調整其他
		# 16 棟建築時的參考基準,不走 _scaled_costs()/_scaled_days() 佔位公式。
		Building.new(
			GameEnums.BuildingType.LUMBER_MILL,               ## 建築類型(同時也是識別碼)
			"伐木場",                                         ## 中文名稱
			"派遣力量角色採集木材,是最基礎的木材產地。",             ## ACTION PANEL 描述文字
			GameEnums.PotentialType.STRENGTH,                 ## 素質需求
			GameEnums.ResourceType.WOOD,                      ## 產出資源
			5,                                                ## 基礎產量
			{},                                               ## 每次結算消耗資源
			{GameEnums.ResourceType.WOOD: 20},                ## 建造(0→1)耗材
			2,                                                ## 建造天數
			[                                                 ## 升級(1→9)耗材表,手動對標
				{GameEnums.ResourceType.WOOD: 30},
				{GameEnums.ResourceType.WOOD: 45, GameEnums.ResourceType.STONE: 10},
				{GameEnums.ResourceType.WOOD: 60, GameEnums.ResourceType.STONE: 20},
				{GameEnums.ResourceType.WOOD: 80, GameEnums.ResourceType.STONE: 30, GameEnums.ResourceType.ORE: 10},
				{GameEnums.ResourceType.WOOD: 100, GameEnums.ResourceType.STONE: 40, GameEnums.ResourceType.ORE: 20},
				{GameEnums.ResourceType.WOOD: 130, GameEnums.ResourceType.STONE: 60, GameEnums.ResourceType.ORE: 30},
				{GameEnums.ResourceType.WOOD: 160, GameEnums.ResourceType.STONE: 80, GameEnums.ResourceType.ORE: 40},
				{GameEnums.ResourceType.WOOD: 200, GameEnums.ResourceType.STONE: 100, GameEnums.ResourceType.ORE: 60},
			],
			[2, 3, 3, 4, 4, 5, 5, 6]                         ## 升級天數表,手動對標
		),
		Building.new(
			GameEnums.BuildingType.QUARRY,                    ## 建築類型(同時也是識別碼)
			"採石場",                                         ## 中文名稱
			"派遣力量角色開採石材,屬於高階內政。",                 ## ACTION PANEL 描述文字
			GameEnums.PotentialType.STRENGTH,                 ## 素質需求
			GameEnums.ResourceType.STONE,                     ## 產出資源
			3,                                                ## 基礎產量
			{},                                               ## 每次結算消耗資源
			{GameEnums.ResourceType.STONE: 15, GameEnums.ResourceType.ORE: 5}, ## 建造(0→1)耗材
			2,                                                ## 建造天數
			_scaled_costs({GameEnums.ResourceType.STONE: 15, GameEnums.ResourceType.ORE: 5}), ## 升級(1→9)耗材表
			_scaled_days(2)                                  ## 升級天數表
		),
		Building.new(
			GameEnums.BuildingType.FARM,                      ## 建築類型(同時也是識別碼)
			"農田",                                           ## 中文名稱
			"派遣體質角色進行農耕,產出糧食。",                     ## ACTION PANEL 描述文字
			GameEnums.PotentialType.VITALITY,                 ## 素質需求
			GameEnums.ResourceType.FOOD,                      ## 產出資源
			5,                                                ## 基礎產量
			{},                                               ## 每次結算消耗資源
			{GameEnums.ResourceType.WOOD: 8, GameEnums.ResourceType.FOOD: 5}, ## 建造(0→1)耗材
			2,                                                ## 建造天數
			_scaled_costs({GameEnums.ResourceType.WOOD: 8, GameEnums.ResourceType.FOOD: 5}), ## 升級(1→9)耗材表
			_scaled_days(2)                                  ## 升級天數表
		),
		Building.new(
			GameEnums.BuildingType.MINE,                      ## 建築類型(同時也是識別碼)
			"採礦場",                                         ## 中文名稱
			"派遣體質角色採礦,屬於高階內政。",                     ## ACTION PANEL 描述文字
			GameEnums.PotentialType.VITALITY,                 ## 素質需求
			GameEnums.ResourceType.ORE,                       ## 產出資源
			3,                                                ## 基礎產量
			{},                                               ## 每次結算消耗資源
			{GameEnums.ResourceType.STONE: 15, GameEnums.ResourceType.ORE: 10}, ## 建造(0→1)耗材
			2,                                                ## 建造天數
			_scaled_costs({GameEnums.ResourceType.STONE: 15, GameEnums.ResourceType.ORE: 10}), ## 升級(1→9)耗材表
			_scaled_days(2)                                  ## 升級天數表
		),
		Building.new(
			GameEnums.BuildingType.CARAVAN,                   ## 建築類型(同時也是識別碼)
			"商隊站",                                         ## 中文名稱
			"派遣敏捷角色進行商業活動,產出金錢。",                  ## ACTION PANEL 描述文字
			GameEnums.PotentialType.AGILITY,                  ## 素質需求
			GameEnums.ResourceType.GOLD,                      ## 產出資源
			5,                                                ## 基礎產量
			{},                                               ## 每次結算消耗資源
			{GameEnums.ResourceType.WOOD: 10, GameEnums.ResourceType.GOLD: 5}, ## 建造(0→1)耗材
			2,                                                ## 建造天數
			_scaled_costs({GameEnums.ResourceType.WOOD: 10, GameEnums.ResourceType.GOLD: 5}), ## 升級(1→9)耗材表
			_scaled_days(2)                                  ## 升級天數表
		),
		Building.new(
			GameEnums.BuildingType.BLACK_MARKET,              ## 建築類型(同時也是識別碼)
			"黑市",                                           ## 中文名稱
			"派遣敏捷角色進行地下交易,屬於高階內政。",              ## ACTION PANEL 描述文字
			GameEnums.PotentialType.AGILITY,                  ## 素質需求
			GameEnums.ResourceType.CONTRABAND,                ## 產出資源
			3,                                                ## 基礎產量
			{},                                               ## 每次結算消耗資源
			{GameEnums.ResourceType.GOLD: 15, GameEnums.ResourceType.CONTRABAND: 5}, ## 建造(0→1)耗材
			2,                                                ## 建造天數
			_scaled_costs({GameEnums.ResourceType.GOLD: 15, GameEnums.ResourceType.CONTRABAND: 5}), ## 升級(1→9)耗材表
			_scaled_days(2)                                  ## 升級天數表
		),
		Building.new(
			GameEnums.BuildingType.HUNTING_GROUND,            ## 建築類型(同時也是識別碼)
			"狩獵場",                                         ## 中文名稱
			"派遣靈巧角色進行狩獵,產出毛皮。",                     ## ACTION PANEL 描述文字
			GameEnums.PotentialType.DEXTERITY,                ## 素質需求
			GameEnums.ResourceType.FUR,                       ## 產出資源
			5,                                                ## 基礎產量
			{},                                               ## 每次結算消耗資源
			{GameEnums.ResourceType.WOOD: 10, GameEnums.ResourceType.FUR: 5}, ## 建造(0→1)耗材
			2,                                                ## 建造天數
			_scaled_costs({GameEnums.ResourceType.WOOD: 10, GameEnums.ResourceType.FUR: 5}), ## 升級(1→9)耗材表
			_scaled_days(2)                                  ## 升級天數表
		),
		Building.new(
			GameEnums.BuildingType.WORKSHOP,                  ## 建築類型(同時也是識別碼)
			"工匠坊",                                         ## 中文名稱
			"派遣靈巧角色進行製作,消耗木材/石材/鐵礦/毛皮,屬於高階內政。", ## ACTION PANEL 描述文字
			GameEnums.PotentialType.DEXTERITY,                ## 素質需求
			GameEnums.ResourceType.CRAFT,                     ## 產出資源
			3,                                                ## 基礎產量
			{                                                 ## 每次結算消耗資源
				GameEnums.ResourceType.WOOD: 2,
				GameEnums.ResourceType.STONE: 2,
				GameEnums.ResourceType.ORE: 1,
				GameEnums.ResourceType.FUR: 1,
			},
			{                                                 ## 建造(0→1)耗材
				GameEnums.ResourceType.WOOD: 5, GameEnums.ResourceType.STONE: 5,
				GameEnums.ResourceType.ORE: 5, GameEnums.ResourceType.FUR: 5,
			},
			2,                                                ## 建造天數
			_scaled_costs({                                  ## 升級(1→9)耗材表
				GameEnums.ResourceType.WOOD: 5, GameEnums.ResourceType.STONE: 5,
				GameEnums.ResourceType.ORE: 5, GameEnums.ResourceType.FUR: 5,
			}),
			_scaled_days(2)                                  ## 升級天數表
		),
		Building.new(
			GameEnums.BuildingType.SCRIPTORIUM,               ## 建築類型(同時也是識別碼)
			"抄書院",                                         ## 中文名稱
			"派遣智慧角色抄寫書籍,產出書本。",                     ## ACTION PANEL 描述文字
			GameEnums.PotentialType.INTELLIGENCE,             ## 素質需求
			GameEnums.ResourceType.BOOK,                      ## 產出資源
			5,                                                ## 基礎產量
			{},                                               ## 每次結算消耗資源
			{GameEnums.ResourceType.WOOD: 10, GameEnums.ResourceType.BOOK: 5}, ## 建造(0→1)耗材
			2,                                                ## 建造天數
			_scaled_costs({GameEnums.ResourceType.WOOD: 10, GameEnums.ResourceType.BOOK: 5}), ## 升級(1→9)耗材表
			_scaled_days(2)                                  ## 升級天數表
		),
		Building.new(
			GameEnums.BuildingType.RESEARCH_INSTITUTE,        ## 建築類型(同時也是識別碼)
			"科學研究所",                                      ## 中文名稱
			"派遣智慧角色進行研究,消耗書本,產出科研用於科技系統,屬於高階內政。", ## ACTION PANEL 描述文字
			GameEnums.PotentialType.INTELLIGENCE,             ## 素質需求
			GameEnums.ResourceType.RESEARCH,                  ## 產出資源
			3,                                                ## 基礎產量
			{GameEnums.ResourceType.BOOK: 2},                 ## 每次結算消耗資源
			{GameEnums.ResourceType.BOOK: 10, GameEnums.ResourceType.RESEARCH: 5}, ## 建造(0→1)耗材
			2,                                                ## 建造天數
			_scaled_costs({GameEnums.ResourceType.BOOK: 10, GameEnums.ResourceType.RESEARCH: 5}), ## 升級(1→9)耗材表
			_scaled_days(2)                                  ## 升級天數表
		),
		Building.new(
			GameEnums.BuildingType.ALTAR,                     ## 建築類型(同時也是識別碼)
			"祭壇",                                           ## 中文名稱
			"派遣意志角色進行祭祀,產出信仰。",                     ## ACTION PANEL 描述文字
			GameEnums.PotentialType.MENTALITY,                ## 素質需求
			GameEnums.ResourceType.FAITH,                     ## 產出資源
			5,                                                ## 基礎產量
			{},                                               ## 每次結算消耗資源
			{GameEnums.ResourceType.STONE: 10, GameEnums.ResourceType.FAITH: 5}, ## 建造(0→1)耗材
			2,                                                ## 建造天數
			_scaled_costs({GameEnums.ResourceType.STONE: 10, GameEnums.ResourceType.FAITH: 5}), ## 升級(1→9)耗材表
			_scaled_days(2)                                  ## 升級天數表
		),
		Building.new(
			GameEnums.BuildingType.FORBIDDEN_ALTAR,           ## 建築類型(同時也是識別碼)
			"禁忌祭壇",                                        ## 中文名稱
			"派遣意志角色進行禁忌祭祀,消耗信仰並產出詛咒,屬於高階內政。", ## ACTION PANEL 描述文字
			GameEnums.PotentialType.MENTALITY,                ## 素質需求
			GameEnums.ResourceType.CURSE,                     ## 產出資源
			3,                                                ## 基礎產量
			{GameEnums.ResourceType.FAITH: 2},                ## 每次結算消耗資源
			{GameEnums.ResourceType.FAITH: 10, GameEnums.ResourceType.CURSE: 5}, ## 建造(0→1)耗材
			2,                                                ## 建造天數
			_scaled_costs({GameEnums.ResourceType.FAITH: 10, GameEnums.ResourceType.CURSE: 5}), ## 升級(1→9)耗材表
			_scaled_days(2)                                  ## 升級天數表
		),
	]
