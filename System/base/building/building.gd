class_name Building
extends RefCounted

## 根據地上單一建築的靜態資料(見 BuildingLibrary.get_all())。跟 System/map/map_object.gd
## 的 MapObject 同一種設計:類型/範圍集中在工廠函式回傳,不要散落寫在 base.tscn 或
## base_system.gd。生產類建築(potential_type/produces 不為 -1)可以派遣角色,見
## BaseDispatchStore;非生產類建築(城鎮中心/住宅區/醫療所/倉庫/兵營)目前只有資料
## 定義,功能尚未實作。
##
## 不存獨立的 position 欄位——只會跟 territory_polygon 對不上、需要兩邊手動同步,
## 需要中心點(畫面標籤位置等)一律呼叫 center() 現算,見該函式註解。

var id: String
var name: String
var type: GameEnums.BuildingType
## GameEnums.PotentialType,-1 表示非生產類建築,不吃素質、不能派遣角色
var potential_type: int
## GameEnums.ResourceType,-1 表示無產出
var produces: int
var base_yield: int
## 每次每日結算消耗的資源,GameEnums.ResourceType -> int,空字典表示不消耗任何資源
var consumes: Dictionary
## 建築圖示範圍多邊形(跟 Background 同一個座標系的絕對座標),供點擊命中判定/畫面
## 繪製使用(見 BaseSystem.pick_building()、Scenes/Base/building_visual.gd),同
## MapObject.territory_polygon 的設計。
var territory_polygon: PackedVector2Array
## 升級耗材表:index i = 從第 i 級升到第 i+1 級所需資源(GameEnums.ResourceType -> int)。
## 陣列長度就是這棟建築的最高等級,目前全部建築統一 9 級對應 GameEnums.RankType 的
## F~SSS。實際升級/目前等級是會變動的玩家進度,不存在這裡——見
## Scripts/Autoload/base_building_progress_store.gd。
var upgrade_costs: Array[Dictionary]


func _init(
	p_id: String,
	p_name: String,
	p_type: GameEnums.BuildingType,
	p_potential_type: int = -1,
	p_produces: int = -1,
	p_base_yield: int = 0,
	p_consumes: Dictionary = {},
	p_territory_polygon: PackedVector2Array = PackedVector2Array(),
	p_upgrade_costs: Array[Dictionary] = []
) -> void:
	id = p_id
	name = p_name
	type = p_type
	potential_type = p_potential_type
	produces = p_produces
	base_yield = p_base_yield
	consumes = p_consumes
	territory_polygon = p_territory_polygon
	upgrade_costs = p_upgrade_costs


func max_level() -> int:
	return upgrade_costs.size()


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
