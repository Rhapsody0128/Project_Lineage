class_name BuildingLibrary
extends RefCounted

## 根據地全部 18 種建築的集中定義(遊戲企劃設定總整理.md 六十八節)。這裡只放遊戲數值
## (名稱/描述/素質需求/產出/耗材/天數),畫面座標(territory_polygon)分開放在
## System/base/building/building_positions.gd,由 Building._init() 依 type 自動查出
## (見 building.gd),這裡不用傳、也不用維護額外的字串 id——type 本身就是識別碼。
##
## 每個 Building.new() 呼叫一個參數一行,後面用註解標明對應 Building._init() 的哪個
## 欄位(順序見 building.gd),方便掃視/調整個別數值,不用回頭數第幾個參數。
##
## 全部 18 棟建築共用同一條建造/升級天數曲線(BUILD_DAYS/UPGRADE_DAYS,見「根據地經濟
## 藍圖」設計文件):0→1 固定 30 天,1→2...8→9 依序拉長。12 棟生產類建築跟 6 棟非生產類
## 建築(STRONGHOLD/RESIDENTIAL/CLINIC/WAREHOUSE/BARRACKS/FORGE)的 base_yield/build_cost/
## upgrade_costs 都依「根據地內政系統設計」文件逐棟手動填寫(見下方各建築註解對應的
## 資源鏈),沒有任何佔位公式展開的數字。
##
## FORGE(鐵匠鋪)的素質加成機制本身尚未實作(比照 CLINIC/BARRACKS 等非生產類建築,
## 目前只有資料定義),但 territory_polygon 已經是正式座標(見 building_positions.gd)。

const BUILD_DAYS := 30
const UPGRADE_DAYS: Array[int] = [41, 55, 74, 100, 135, 182, 245, 331]


static func get_all() -> Array[Building]:
	return [
		Building.new(
			GameEnums.BuildingType.STRONGHOLD,               ## 建築類型(同時也是識別碼)
			"大本營",                                        ## 中文名稱
			"根據地核心,決定所有其他建築的最高等級上限,自身不產出、不加容量、不給全局加成。", ## ACTION PANEL 描述文字
			-1,                                              ## 素質需求(-1 = 非生產類建築)
			-1,                                              ## 產出資源(-1 = 無產出)
			0,                                               ## 基礎產量
			{GameEnums.ResourceType.WOOD: 60, GameEnums.ResourceType.GOLD: 40}, ## 建造(0→1)耗材
			BUILD_DAYS,                                      ## 建造天數
			[                                                ## 升級(1→9)耗材表:刻意吃遍所有資源鏈,
			                                                  ## 逼玩家先把經濟建立完整才推得動高等級
				{GameEnums.ResourceType.WOOD: 60, GameEnums.ResourceType.STONE: 40},
				{GameEnums.ResourceType.WOOD: 85, GameEnums.ResourceType.STONE: 55, GameEnums.ResourceType.GOLD: 55},
				{GameEnums.ResourceType.STONE: 75, GameEnums.ResourceType.ORE: 50, GameEnums.ResourceType.GOLD: 110},
				{GameEnums.ResourceType.STONE: 100, GameEnums.ResourceType.ORE: 70, GameEnums.ResourceType.GOLD: 150, GameEnums.ResourceType.TOOL: 25},
				{GameEnums.ResourceType.ORE: 95, GameEnums.ResourceType.GOLD: 200, GameEnums.ResourceType.TOOL: 35, GameEnums.ResourceType.BOOK: 70},
				{GameEnums.ResourceType.GOLD: 270, GameEnums.ResourceType.TOOL: 45, GameEnums.ResourceType.BOOK: 95, GameEnums.ResourceType.RESEARCH: 25},
				{GameEnums.ResourceType.GOLD: 360, GameEnums.ResourceType.TOOL: 60, GameEnums.ResourceType.RESEARCH: 35, GameEnums.ResourceType.FAITH: 85},
				{GameEnums.ResourceType.GOLD: 495, GameEnums.ResourceType.TOOL: 85, GameEnums.ResourceType.RESEARCH: 50, GameEnums.ResourceType.FAITH: 115, GameEnums.ResourceType.CURSE: 25},
			],
			UPGRADE_DAYS                                     ## 升級天數表
		),
		Building.new(
			GameEnums.BuildingType.RESIDENTIAL,               ## 建築類型(同時也是識別碼)
			"住宅區",                                         ## 中文名稱
			"增加根據地可容納的角色總數(招募/婚生子女上限,跟戰場出戰人數無關)。", ## ACTION PANEL 描述文字
			-1,                                               ## 素質需求(-1 = 非生產類建築)
			-1,                                               ## 產出資源(-1 = 無產出)
			0,                                                ## 基礎產量
			{GameEnums.ResourceType.WOOD: 90},                ## 建造(0→1)耗材
			BUILD_DAYS,                                       ## 建造天數
			[                                                 ## 升級(1→9)耗材表
				{GameEnums.ResourceType.WOOD: 40, GameEnums.ResourceType.STONE: 20},
				{GameEnums.ResourceType.WOOD: 55, GameEnums.ResourceType.STONE: 30},
				{GameEnums.ResourceType.WOOD: 75, GameEnums.ResourceType.STONE: 40},
				{GameEnums.ResourceType.WOOD: 100, GameEnums.ResourceType.STONE: 55},
				{GameEnums.ResourceType.WOOD: 135, GameEnums.ResourceType.STONE: 70},
				{GameEnums.ResourceType.WOOD: 180, GameEnums.ResourceType.STONE: 95},
				{GameEnums.ResourceType.WOOD: 245, GameEnums.ResourceType.STONE: 125},
				{GameEnums.ResourceType.WOOD: 330, GameEnums.ResourceType.STONE: 170},
			],
			UPGRADE_DAYS                                      ## 升級天數表
		),
		Building.new(
			GameEnums.BuildingType.CLINIC,                    ## 建築類型(同時也是識別碼)
			"醫療所",                                         ## 中文名稱
			"提升角色每日 HP 回復速度,並延後角色進入衰老期的年齡。",   ## ACTION PANEL 描述文字
			-1,                                               ## 素質需求(-1 = 非生產類建築)
			-1,                                               ## 產出資源(-1 = 無產出)
			0,                                                ## 基礎產量
			{GameEnums.ResourceType.STONE: 45},               ## 建造(0→1)耗材
			BUILD_DAYS,                                       ## 建造天數
			[                                                 ## 升級(1→9)耗材表
				{GameEnums.ResourceType.FOOD: 40},
				{GameEnums.ResourceType.FOOD: 55},
				{GameEnums.ResourceType.FOOD: 75, GameEnums.ResourceType.BOOK: 35},
				{GameEnums.ResourceType.FOOD: 100, GameEnums.ResourceType.BOOK: 50},
				{GameEnums.ResourceType.FOOD: 135, GameEnums.ResourceType.BOOK: 65},
				{GameEnums.ResourceType.FOOD: 180, GameEnums.ResourceType.BOOK: 90, GameEnums.ResourceType.TOOL: 30},
				{GameEnums.ResourceType.FOOD: 245, GameEnums.ResourceType.BOOK: 120, GameEnums.ResourceType.TOOL: 40},
				{GameEnums.ResourceType.FOOD: 330, GameEnums.ResourceType.BOOK: 165, GameEnums.ResourceType.TOOL: 55},
			],
			UPGRADE_DAYS                                      ## 升級天數表
		),
		Building.new(
			GameEnums.BuildingType.WAREHOUSE,                 ## 建築類型(同時也是識別碼)
			"倉庫",                                           ## 中文名稱
			"增加各種資源的儲存上限。",                            ## ACTION PANEL 描述文字
			-1,                                               ## 素質需求(-1 = 非生產類建築)
			-1,                                               ## 產出資源(-1 = 無產出)
			0,                                                ## 基礎產量
			{GameEnums.ResourceType.WOOD: 90},                ## 建造(0→1)耗材
			BUILD_DAYS,                                       ## 建造天數
			[                                                 ## 升級(1→9)耗材表
				{GameEnums.ResourceType.STONE: 40},
				{GameEnums.ResourceType.STONE: 55},
				{GameEnums.ResourceType.STONE: 75, GameEnums.ResourceType.ORE: 35},
				{GameEnums.ResourceType.STONE: 100, GameEnums.ResourceType.ORE: 50},
				{GameEnums.ResourceType.STONE: 135, GameEnums.ResourceType.ORE: 65},
				{GameEnums.ResourceType.STONE: 180, GameEnums.ResourceType.ORE: 90, GameEnums.ResourceType.TOOL: 30},
				{GameEnums.ResourceType.STONE: 245, GameEnums.ResourceType.ORE: 120, GameEnums.ResourceType.TOOL: 40},
				{GameEnums.ResourceType.STONE: 330, GameEnums.ResourceType.ORE: 165, GameEnums.ResourceType.TOOL: 55},
			],
			UPGRADE_DAYS                                      ## 升級天數表
		),
		Building.new(
			GameEnums.BuildingType.BARRACKS,                  ## 建築類型(同時也是識別碼)
			"兵營",                                           ## 中文名稱
			"傳授主動技能、訓練已學會的被動技能,可傳授/訓練的最高 Rank 依等級提升;不影響戰場 COST。", ## ACTION PANEL 描述文字
			-1,                                               ## 素質需求(-1 = 非生產類建築)
			-1,                                               ## 產出資源(-1 = 無產出)
			0,                                                ## 基礎產量
			{GameEnums.ResourceType.WOOD: 15, GameEnums.ResourceType.STONE: 15, GameEnums.ResourceType.ORE: 10}, ## 建造(0→1)耗材
			BUILD_DAYS,                                       ## 建造天數
			[                                                 ## 升級(1→9)耗材表
				{GameEnums.ResourceType.ORE: 30, GameEnums.ResourceType.GOLD: 30},
				{GameEnums.ResourceType.ORE: 40, GameEnums.ResourceType.GOLD: 40},
				{GameEnums.ResourceType.ORE: 50, GameEnums.ResourceType.GOLD: 75},
				{GameEnums.ResourceType.ORE: 70, GameEnums.ResourceType.GOLD: 100, GameEnums.ResourceType.TOOL: 20},
				{GameEnums.ResourceType.ORE: 95, GameEnums.ResourceType.GOLD: 135, GameEnums.ResourceType.TOOL: 30},
				{GameEnums.ResourceType.ORE: 125, GameEnums.ResourceType.GOLD: 180, GameEnums.ResourceType.TOOL: 40},
				{GameEnums.ResourceType.ORE: 170, GameEnums.ResourceType.GOLD: 245, GameEnums.ResourceType.TOOL: 55},
				{GameEnums.ResourceType.ORE: 230, GameEnums.ResourceType.GOLD: 330, GameEnums.ResourceType.TOOL: 75},
			],
			UPGRADE_DAYS                                      ## 升級天數表
		),
		Building.new(
			GameEnums.BuildingType.FORGE,                     ## 建築類型(同時也是識別碼)
			"鐵匠鋪",                                          ## 中文名稱
			"打造裝備,升級後提升對應武器類型的全體基礎素質。",         ## ACTION PANEL 描述文字
			-1,                                               ## 素質需求(-1 = 非生產類建築)
			-1,                                               ## 產出資源(-1 = 無產出)
			0,                                                ## 基礎產量
			{GameEnums.ResourceType.ORE: 45},                 ## 建造(0→1)耗材
			BUILD_DAYS,                                       ## 建造天數
			[                                                 ## 升級(1→9)耗材表
				{GameEnums.ResourceType.ORE: 40, GameEnums.ResourceType.TOOL: 20},
				{GameEnums.ResourceType.ORE: 55, GameEnums.ResourceType.TOOL: 30},
				{GameEnums.ResourceType.ORE: 75, GameEnums.ResourceType.TOOL: 40},
				{GameEnums.ResourceType.ORE: 100, GameEnums.ResourceType.TOOL: 55},
				{GameEnums.ResourceType.ORE: 135, GameEnums.ResourceType.TOOL: 70},
				{GameEnums.ResourceType.ORE: 180, GameEnums.ResourceType.TOOL: 95},
				{GameEnums.ResourceType.ORE: 245, GameEnums.ResourceType.TOOL: 125},
				{GameEnums.ResourceType.ORE: 330, GameEnums.ResourceType.TOOL: 170},
			],
			UPGRADE_DAYS                                     ## 升級天數表
		),
		Building.new(
			GameEnums.BuildingType.LUMBER_MILL,               ## 建築類型(同時也是識別碼)
			"伐木場",                                         ## 中文名稱
			"派遣力量角色採集木材,是最基礎的木材產地。",             ## ACTION PANEL 描述文字
			GameEnums.PotentialType.STRENGTH,                 ## 素質需求
			GameEnums.ResourceType.WOOD,                      ## 產出資源
			12,                                               ## 基礎產量
			{GameEnums.ResourceType.WOOD: 90},                ## 建造(0→1)耗材
			BUILD_DAYS,                                       ## 建造天數
			[                                                 ## 升級(1→9)耗材表
				{GameEnums.ResourceType.STONE: 40},
				{GameEnums.ResourceType.STONE: 55},
				{GameEnums.ResourceType.STONE: 75, GameEnums.ResourceType.ORE: 50},
				{GameEnums.ResourceType.STONE: 100, GameEnums.ResourceType.ORE: 70},
				{GameEnums.ResourceType.STONE: 135, GameEnums.ResourceType.ORE: 95},
				{GameEnums.ResourceType.STONE: 180, GameEnums.ResourceType.ORE: 125},
				{GameEnums.ResourceType.STONE: 245, GameEnums.ResourceType.ORE: 170},
				{GameEnums.ResourceType.STONE: 330, GameEnums.ResourceType.ORE: 230},
			],
			UPGRADE_DAYS                                     ## 升級天數表
		),
		Building.new(
			GameEnums.BuildingType.HUNTING_GROUND,            ## 建築類型(同時也是識別碼)
			"狩獵場",                                         ## 中文名稱
			"派遣靈巧角色進行狩獵,產出毛皮。",                     ## ACTION PANEL 描述文字
			GameEnums.PotentialType.DEXTERITY,                ## 素質需求
			GameEnums.ResourceType.FUR,                       ## 產出資源
			11,                                               ## 基礎產量
			{GameEnums.ResourceType.WOOD: 90},                ## 建造(0→1)耗材
			BUILD_DAYS,                                       ## 建造天數
			[                                                 ## 升級(1→9)耗材表
				{GameEnums.ResourceType.STONE: 40},
				{GameEnums.ResourceType.STONE: 55},
				{GameEnums.ResourceType.STONE: 75, GameEnums.ResourceType.ORE: 50},
				{GameEnums.ResourceType.STONE: 100, GameEnums.ResourceType.ORE: 70},
				{GameEnums.ResourceType.STONE: 135, GameEnums.ResourceType.ORE: 95},
				{GameEnums.ResourceType.STONE: 180, GameEnums.ResourceType.ORE: 125},
				{GameEnums.ResourceType.STONE: 245, GameEnums.ResourceType.ORE: 170},
				{GameEnums.ResourceType.STONE: 330, GameEnums.ResourceType.ORE: 230},
			],
			UPGRADE_DAYS                                     ## 升級天數表
		),
		Building.new(
			GameEnums.BuildingType.CARAVAN,                   ## 建築類型(同時也是識別碼)
			"商隊站",                                         ## 中文名稱
			"派遣敏捷角色進行商業活動,產出金錢。",                  ## ACTION PANEL 描述文字
			GameEnums.PotentialType.AGILITY,                  ## 素質需求
			GameEnums.ResourceType.GOLD,                      ## 產出資源
			10,                                               ## 基礎產量
			{GameEnums.ResourceType.WOOD: 90},                ## 建造(0→1)耗材
			BUILD_DAYS,                                       ## 建造天數
			[                                                 ## 升級(1→9)耗材表
				{GameEnums.ResourceType.GOLD: 80},
				{GameEnums.ResourceType.GOLD: 110},
				{GameEnums.ResourceType.GOLD: 150, GameEnums.ResourceType.FUR: 75},
				{GameEnums.ResourceType.GOLD: 200, GameEnums.ResourceType.FUR: 105},
				{GameEnums.ResourceType.GOLD: 270, GameEnums.ResourceType.FUR: 145},
				{GameEnums.ResourceType.GOLD: 360, GameEnums.ResourceType.FUR: 190},
				{GameEnums.ResourceType.GOLD: 490, GameEnums.ResourceType.FUR: 255},
				{GameEnums.ResourceType.GOLD: 660, GameEnums.ResourceType.FUR: 345},
			],
			UPGRADE_DAYS                                     ## 升級天數表
		),
		Building.new(
			GameEnums.BuildingType.FARM,                      ## 建築類型(同時也是識別碼)
			"農田",                                           ## 中文名稱
			"派遣體質角色進行農耕,產出糧食。",                     ## ACTION PANEL 描述文字
			GameEnums.PotentialType.VITALITY,                 ## 素質需求
			GameEnums.ResourceType.FOOD,                      ## 產出資源
			9,                                                ## 基礎產量
			{GameEnums.ResourceType.WOOD: 90},                ## 建造(0→1)耗材
			BUILD_DAYS,                                       ## 建造天數
			[                                                 ## 升級(1→9)耗材表
				{GameEnums.ResourceType.STONE: 40},
				{GameEnums.ResourceType.STONE: 55},
				{GameEnums.ResourceType.STONE: 75, GameEnums.ResourceType.ORE: 50},
				{GameEnums.ResourceType.STONE: 100, GameEnums.ResourceType.ORE: 70},
				{GameEnums.ResourceType.STONE: 135, GameEnums.ResourceType.ORE: 95},
				{GameEnums.ResourceType.STONE: 180, GameEnums.ResourceType.ORE: 125},
				{GameEnums.ResourceType.STONE: 245, GameEnums.ResourceType.ORE: 170},
				{GameEnums.ResourceType.STONE: 330, GameEnums.ResourceType.ORE: 230},
			],
			UPGRADE_DAYS                                     ## 升級天數表
		),
		Building.new(
			GameEnums.BuildingType.SCRIPTORIUM,               ## 建築類型(同時也是識別碼)
			"抄書院",                                         ## 中文名稱
			"派遣智慧角色抄寫書籍,消耗毛皮製作紙張,產出書本。",     ## ACTION PANEL 描述文字
			GameEnums.PotentialType.INTELLIGENCE,             ## 素質需求
			GameEnums.ResourceType.BOOK,                      ## 產出資源
			8,                                                ## 基礎產量
			{GameEnums.ResourceType.WOOD: 90},                ## 建造(0→1)耗材
			BUILD_DAYS,                                       ## 建造天數
			[                                                 ## 升級(1→9)耗材表
				{GameEnums.ResourceType.STONE: 40},
				{GameEnums.ResourceType.STONE: 55},
				{GameEnums.ResourceType.STONE: 75, GameEnums.ResourceType.FUR: 75},
				{GameEnums.ResourceType.STONE: 100, GameEnums.ResourceType.FUR: 105},
				{GameEnums.ResourceType.STONE: 135, GameEnums.ResourceType.FUR: 145},
				{GameEnums.ResourceType.STONE: 180, GameEnums.ResourceType.FUR: 190},
				{GameEnums.ResourceType.STONE: 245, GameEnums.ResourceType.FUR: 255},
				{GameEnums.ResourceType.STONE: 330, GameEnums.ResourceType.FUR: 345},
			],
			UPGRADE_DAYS,                                     ## 升級天數表
			WorkshopRecipe.new("scriptorium_fur", "抄書耗材", {GameEnums.ResourceType.FUR: 2}, 1) ## 固定消耗配方:2 毛皮→1 書本,書本價值點數 8 是毛皮 5 的 round(8÷5)=2 倍,
			## 比例直接對齊價值點數換算(見 base_exchange.gd 開頭「價值點數對照」),
			## 書本因此確實比毛皮更難產。
		),
		Building.new(
			GameEnums.BuildingType.ALTAR,                     ## 建築類型(同時也是識別碼)
			"祭壇",                                           ## 中文名稱
			"派遣意志角色進行祭祀,產出信仰。",                     ## ACTION PANEL 描述文字
			GameEnums.PotentialType.MENTALITY,                ## 素質需求
			GameEnums.ResourceType.FAITH,                     ## 產出資源
			7,                                                ## 基礎產量
			{GameEnums.ResourceType.STONE: 45},               ## 建造(0→1)耗材
			BUILD_DAYS,                                       ## 建造天數
			[                                                 ## 升級(1→9)耗材表
				{GameEnums.ResourceType.GOLD: 80},
				{GameEnums.ResourceType.GOLD: 110},
				{GameEnums.ResourceType.GOLD: 150, GameEnums.ResourceType.TOOL: 25},
				{GameEnums.ResourceType.GOLD: 200, GameEnums.ResourceType.TOOL: 35},
				{GameEnums.ResourceType.GOLD: 270, GameEnums.ResourceType.TOOL: 50},
				{GameEnums.ResourceType.GOLD: 360, GameEnums.ResourceType.TOOL: 65},
				{GameEnums.ResourceType.GOLD: 490, GameEnums.ResourceType.TOOL: 85},
				{GameEnums.ResourceType.GOLD: 660, GameEnums.ResourceType.TOOL: 115},
			],
			UPGRADE_DAYS                                     ## 升級天數表
		),
		Building.new(
			GameEnums.BuildingType.QUARRY,                    ## 建築類型(同時也是識別碼)
			"採石場",                                         ## 中文名稱
			"派遣力量角色開採石材,消耗工具維護採石工序,產出石材。", ## ACTION PANEL 描述文字
			GameEnums.PotentialType.STRENGTH,                 ## 素質需求
			GameEnums.ResourceType.STONE,                     ## 產出資源
			6,                                                ## 基礎產量
			{GameEnums.ResourceType.WOOD: 90},                ## 建造(0→1)耗材
			BUILD_DAYS,                                       ## 建造天數
			[                                                 ## 升級(1→9)耗材表
				{GameEnums.ResourceType.GOLD: 80},
				{GameEnums.ResourceType.GOLD: 110},
				{GameEnums.ResourceType.GOLD: 150, GameEnums.ResourceType.ORE: 50},
				{GameEnums.ResourceType.GOLD: 200, GameEnums.ResourceType.ORE: 70},
				{GameEnums.ResourceType.GOLD: 270, GameEnums.ResourceType.ORE: 95},
				{GameEnums.ResourceType.GOLD: 360, GameEnums.ResourceType.ORE: 125, GameEnums.ResourceType.TOOL: 45},
				{GameEnums.ResourceType.GOLD: 490, GameEnums.ResourceType.ORE: 170, GameEnums.ResourceType.TOOL: 65},
				{GameEnums.ResourceType.GOLD: 660, GameEnums.ResourceType.ORE: 230, GameEnums.ResourceType.TOOL: 85},
			],
			UPGRADE_DAYS,                                     ## 升級天數表
			WorkshopRecipe.new("quarry_tool", "採石耗材", {GameEnums.ResourceType.TOOL: 1}, 4) ## 固定消耗配方:1 工具→4 石材(工具價值點數 40 是石材 10 的 4 倍,見 workshop_recipe_library.gd 開頭註解的換算方法)
		),
		Building.new(
			GameEnums.BuildingType.MINE,                      ## 建築類型(同時也是識別碼)
			"採礦場",                                         ## 中文名稱
			"派遣體質角色採礦,消耗工具維護開採,產出鐵礦。",        ## ACTION PANEL 描述文字
			GameEnums.PotentialType.VITALITY,                 ## 素質需求
			GameEnums.ResourceType.ORE,                       ## 產出資源
			5,                                                ## 基礎產量
			{GameEnums.ResourceType.WOOD: 90},                ## 建造(0→1)耗材
			BUILD_DAYS,                                       ## 建造天數
			[                                                 ## 升級(1→9)耗材表
				{GameEnums.ResourceType.STONE: 40},
				{GameEnums.ResourceType.STONE: 55},
				{GameEnums.ResourceType.STONE: 75, GameEnums.ResourceType.ORE: 50},
				{GameEnums.ResourceType.STONE: 100, GameEnums.ResourceType.ORE: 70},
				{GameEnums.ResourceType.STONE: 135, GameEnums.ResourceType.ORE: 95},
				{GameEnums.ResourceType.STONE: 180, GameEnums.ResourceType.ORE: 125, GameEnums.ResourceType.TOOL: 45},
				{GameEnums.ResourceType.STONE: 245, GameEnums.ResourceType.ORE: 170, GameEnums.ResourceType.TOOL: 65},
				{GameEnums.ResourceType.STONE: 330, GameEnums.ResourceType.ORE: 230, GameEnums.ResourceType.TOOL: 85},
			],
			UPGRADE_DAYS,                                     ## 升級天數表
			WorkshopRecipe.new("mine_tool", "採礦耗材", {GameEnums.ResourceType.TOOL: 1}, 3) ## 固定消耗配方:1 工具→3 鐵礦(工具價值點數 40 約是鐵礦 12 的 3 倍)
		),
		Building.new(
			GameEnums.BuildingType.BLACK_MARKET,              ## 建築類型(同時也是識別碼)
			"黑市",                                           ## 中文名稱
			"派遣敏捷角色進行地下交易,消耗金錢打點關係,產出贓物。", ## ACTION PANEL 描述文字
			GameEnums.PotentialType.AGILITY,                  ## 素質需求
			GameEnums.ResourceType.CONTRABAND,                ## 產出資源
			4,                                                ## 基礎產量
			{GameEnums.ResourceType.STONE: 45},               ## 建造(0→1)耗材
			BUILD_DAYS,                                       ## 建造天數
			[                                                 ## 升級(1→9)耗材表
				{GameEnums.ResourceType.GOLD: 80},
				{GameEnums.ResourceType.GOLD: 110},
				{GameEnums.ResourceType.GOLD: 150, GameEnums.ResourceType.FUR: 75},
				{GameEnums.ResourceType.GOLD: 200, GameEnums.ResourceType.FUR: 105},
				{GameEnums.ResourceType.GOLD: 270, GameEnums.ResourceType.FUR: 145},
				{GameEnums.ResourceType.GOLD: 360, GameEnums.ResourceType.FUR: 190, GameEnums.ResourceType.ORE: 90},
				{GameEnums.ResourceType.GOLD: 490, GameEnums.ResourceType.FUR: 255, GameEnums.ResourceType.ORE: 125},
				{GameEnums.ResourceType.GOLD: 660, GameEnums.ResourceType.FUR: 345, GameEnums.ResourceType.ORE: 165},
			],
			UPGRADE_DAYS,                                     ## 升級天數表
			WorkshopRecipe.new("black_market_gold", "地下交易耗材", {GameEnums.ResourceType.GOLD: 3}, 1) ## 固定消耗配方:3 金錢→1 贓物(贓物價值點數 15 約是金錢 6 的 2.5 倍)
		),
		Building.new(
			GameEnums.BuildingType.WORKSHOP,                  ## 建築類型(同時也是識別碼)
			"工匠坊",                                         ## 中文名稱
			"派遣靈巧角色進行製作,依配方消耗原料,產出工具。",         ## ACTION PANEL 描述文字
			GameEnums.PotentialType.DEXTERITY,                ## 素質需求
			GameEnums.ResourceType.TOOL,                     ## 產出資源
			3,                                                ## 基礎產量
			{GameEnums.ResourceType.WOOD: 90},                ## 建造(0→1)耗材
			BUILD_DAYS,                                       ## 建造天數
			[                                                 ## 升級(1→9)耗材表
				{GameEnums.ResourceType.STONE: 40},
				{GameEnums.ResourceType.STONE: 55},
				{GameEnums.ResourceType.STONE: 75, GameEnums.ResourceType.ORE: 50},
				{GameEnums.ResourceType.STONE: 100, GameEnums.ResourceType.ORE: 70},
				{GameEnums.ResourceType.STONE: 135, GameEnums.ResourceType.ORE: 95},
				{GameEnums.ResourceType.STONE: 180, GameEnums.ResourceType.ORE: 125, GameEnums.ResourceType.FUR: 135, GameEnums.ResourceType.TOOL: 35},
				{GameEnums.ResourceType.STONE: 245, GameEnums.ResourceType.ORE: 170, GameEnums.ResourceType.FUR: 190, GameEnums.ResourceType.TOOL: 45},
				{GameEnums.ResourceType.STONE: 330, GameEnums.ResourceType.ORE: 230, GameEnums.ResourceType.FUR: 250, GameEnums.ResourceType.TOOL: 60},
			],
			UPGRADE_DAYS                                     ## 升級天數表
		),
		Building.new(
			GameEnums.BuildingType.RESEARCH_INSTITUTE,        ## 建築類型(同時也是識別碼)
			"科學研究所",                                      ## 中文名稱
			"派遣智慧角色進行研究,消耗書本查閱資料,產出科研,用於科技系統。", ## ACTION PANEL 描述文字
			GameEnums.PotentialType.INTELLIGENCE,             ## 素質需求
			GameEnums.ResourceType.RESEARCH,                  ## 產出資源
			2,                                                ## 基礎產量
			{GameEnums.ResourceType.STONE: 45},               ## 建造(0→1)耗材
			BUILD_DAYS,                                       ## 建造天數
			[                                                 ## 升級(1→9)耗材表
				{GameEnums.ResourceType.BOOK: 60},
				{GameEnums.ResourceType.BOOK: 85},
				{GameEnums.ResourceType.BOOK: 115, GameEnums.ResourceType.ORE: 50},
				{GameEnums.ResourceType.BOOK: 150, GameEnums.ResourceType.ORE: 70},
				{GameEnums.ResourceType.BOOK: 205, GameEnums.ResourceType.ORE: 95},
				{GameEnums.ResourceType.BOOK: 270, GameEnums.ResourceType.ORE: 125, GameEnums.ResourceType.TOOL: 45, GameEnums.ResourceType.RESEARCH: 35},
				{GameEnums.ResourceType.BOOK: 370, GameEnums.ResourceType.ORE: 170, GameEnums.ResourceType.TOOL: 65, GameEnums.ResourceType.RESEARCH: 45},
				{GameEnums.ResourceType.BOOK: 495, GameEnums.ResourceType.ORE: 230, GameEnums.ResourceType.TOOL: 85, GameEnums.ResourceType.RESEARCH: 60},
			],
			UPGRADE_DAYS,                                     ## 升級天數表
			WorkshopRecipe.new("research_book", "研究耗材", {GameEnums.ResourceType.BOOK: 4}, 1) ## 固定消耗配方:4 書本→1 科研(科研價值點數 30 約是書本 8 的 4 倍)
		),
		Building.new(
			GameEnums.BuildingType.FORBIDDEN_ALTAR,           ## 建築類型(同時也是識別碼)
			"禁忌祭壇",                                        ## 中文名稱
			"派遣意志角色進行禁忌祭祀,消耗信仰,產出詛咒。",         ## ACTION PANEL 描述文字
			GameEnums.PotentialType.MENTALITY,                ## 素質需求
			GameEnums.ResourceType.CURSE,                     ## 產出資源
			1,                                                ## 基礎產量
			{GameEnums.ResourceType.STONE: 45},               ## 建造(0→1)耗材
			BUILD_DAYS,                                       ## 建造天數
			[                                                 ## 升級(1→9)耗材表
				{GameEnums.ResourceType.FAITH: 60},
				{GameEnums.ResourceType.FAITH: 85},
				{GameEnums.ResourceType.FAITH: 115, GameEnums.ResourceType.GOLD: 100},
				{GameEnums.ResourceType.FAITH: 150, GameEnums.ResourceType.GOLD: 140},
				{GameEnums.ResourceType.FAITH: 205, GameEnums.ResourceType.GOLD: 190},
				{GameEnums.ResourceType.FAITH: 270, GameEnums.ResourceType.GOLD: 250, GameEnums.ResourceType.TOOL: 45, GameEnums.ResourceType.CURSE: 35},
				{GameEnums.ResourceType.FAITH: 370, GameEnums.ResourceType.GOLD: 340, GameEnums.ResourceType.TOOL: 65, GameEnums.ResourceType.CURSE: 45},
				{GameEnums.ResourceType.FAITH: 495, GameEnums.ResourceType.GOLD: 460, GameEnums.ResourceType.TOOL: 85, GameEnums.ResourceType.CURSE: 60},
			],
			UPGRADE_DAYS,                                     ## 升級天數表
			WorkshopRecipe.new("forbidden_altar_faith", "禁忌祭祀耗材", {GameEnums.ResourceType.FAITH: 7}, 1) ## 固定消耗配方:7 信仰→1 詛咒(詛咒價值點數 60 約是信仰 9 的 7 倍)
		),
	]
