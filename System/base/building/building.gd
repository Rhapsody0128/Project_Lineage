class_name Building
extends RefCounted

## 根據地上單一建築的靜態資料(見 BuildingLibrary.get_all())。跟 System/map/map_object.gd
## 的 MapObject 同一種設計:類型/範圍集中在工廠函式回傳,不要散落寫在 base.tscn 或
## base_system.gd。生產類建築(potential_type/produces 不為 -1)可以派遣角色,見
## BaseDispatchStore;非生產類建築(城鎮中心/住宅區/醫療所/倉庫/兵營)目前只有資料
## 定義,功能尚未實作。
##
## type(GameEnums.BuildingType)本身就是唯一識別碼,不另外維護一份重複的字串 id——
## 17 種建築類型本來就一一對應,不會有兩棟建築共用同一個 type 卻該視為不同個體的情況。
## 所有拿建築當 Dictionary key 的地方(BaseDispatchStore/BaseBuildingProgressStore)一律
## 用 type。
##
## territory_polygon 不由呼叫端(BuildingLibrary)傳入,_init() 直接拿 type 向
## BuildingPositions.get_polygon() 查——畫面座標資料集中維護在那一份檔案,見
## System/base/building/building_positions.gd 開頭註解。
##
## 不存獨立的 position 欄位——只會跟 territory_polygon 對不上、需要兩邊手動同步,
## 需要中心點(畫面標籤位置等)一律呼叫 center() 現算,見該函式註解。

var type: GameEnums.BuildingType
var name: String
## ACTION PANEL 顯示用的一句介紹文字。
var description: String
## GameEnums.PotentialType,-1 表示非生產類建築,不吃素質、不能派遣角色
var potential_type: int
## GameEnums.ResourceType,-1 表示無產出
var produces: int
var base_yield: int
## 從 0 級「建造」到 1 級所需資源/天數,獨立於升級(見 upgrade_costs)——0 級時建築
## 完全不能用,跟升級中仍正常運作不同。
var build_cost: Dictionary
var build_days: int
## 升級耗材表:index i = 從第 i+1 級升到第 i+2 級所需資源(GameEnums.ResourceType ->
## int),即 index 0 = 1→2 級。陣列長度 + 1(建造那一級)就是這棟建築的最高等級,目前
## 全部建築統一 9 級對應 GameEnums.RankType 的 F~SSS。
var upgrade_costs: Array[Dictionary]
## 跟 upgrade_costs 平行的天數表,index i = 從第 i+1 級升到第 i+2 級要花幾天。
var upgrade_days: Array[int]
## 建築圖示範圍多邊形(跟 Background 同一個座標系的絕對座標),供點擊命中判定/畫面
## 繪製使用(見 BaseSystem.pick_building()、Scenes/Base/building_visual.gd),同
## MapObject.territory_polygon 的設計。由 _init() 依 type 自動從 BuildingPositions 查出。
var territory_polygon: PackedVector2Array


func _init(
	p_type: GameEnums.BuildingType,
	p_name: String,
	p_description: String = "",
	p_potential_type: int = -1,
	p_produces: int = -1,
	p_base_yield: int = 0,
	p_build_cost: Dictionary = {},
	p_build_days: int = 1,
	p_upgrade_costs: Array[Dictionary] = [],
	p_upgrade_days: Array[int] = []
) -> void:
	type = p_type
	name = p_name
	description = p_description
	potential_type = p_potential_type
	produces = p_produces
	base_yield = p_base_yield
	build_cost = p_build_cost
	build_days = p_build_days
	upgrade_costs = p_upgrade_costs
	upgrade_days = p_upgrade_days
	territory_polygon = BuildingPositions.get_polygon(p_type)


## 建造(0→1)算 1 級,之後每個 upgrade_costs 項目再加一級。
func max_level() -> int:
	return 1 + upgrade_costs.size()


func is_production_building() -> bool:
	return potential_type != -1


## territory_polygon 的外框中心點(bounding box center),同 MapObject.position 過去的
## 算法——沒有 polygon 就回傳原點,呼叫端(目前是 building_visual.gd)自行決定要不要
## 特殊處理。
func center() -> Vector2:
	if territory_polygon.is_empty():
		return Vector2.ZERO
	var min_point := territory_polygon[0]
	var max_point := territory_polygon[0]
	for point in territory_polygon:
		min_point.x = minf(min_point.x, point.x)
		min_point.y = minf(min_point.y, point.y)
		max_point.x = maxf(max_point.x, point.x)
		max_point.y = maxf(max_point.y, point.y)
	return (min_point + max_point) / 2.0
