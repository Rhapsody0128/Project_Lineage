extends Node

# =========================================================
# 12 座城堡的佔領狀態(autoload,見 project.godot)。跟 NationFavorStore/BaseDispatchStore
# 同一套慣例:這是 Scenes 層的 session 狀態,不是規則邏輯——城堡本身的難度等級/對應
# 生產建築是靜態查表(見下方兩個 const),佔領與否才是會變動的玩家資料。
#
# 每座城堡對應一種根據地生產建築(見 CASTLE_BUILDING_BY_ID),月產出直接查 BuildingLibrary
# 拿 base_yield/fixed_recipe,固定套用 Lv4 建築效率、不吃角色素質(城堡不用派人力),見
# _monthly_yield_amount()。_ready() 向 WorldTimeStore.controller 註冊每月結算,寫法比照
# base_dispatch_store.gd——這支 autoload 是 Node、應用程式全程存活,直接傳裸方法參照給
# register_month_event() 不會踩 System/time/world_time_controller.gd 開頭提到的 RefCounted
# 生命週期陷阱(那是 RefCounted 事件物件才會遇到的問題)。
# =========================================================

## 佔領狀態變動時發出,讓已經開著的地點選單/HeaderBar 能即時反映。
signal changed

## 城堡 id(MapObject.id)→ 難度等級(GameEnums.RankType)。依「產出基礎值越高→越容易→
## 難度越低」排序配對六個等級,同一地形的兩座城堡刻意配一難一易,不是同地形同等級
## (見 System/event/castle/castle_siege_event.gd 開頭設計備忘)。
const CASTLE_RANK_BY_ID: Dictionary = {
	"PlainsCastle1": GameEnums.RankType.C,
	"PlainsCastle2": GameEnums.RankType.S,
	"MountainsCastle1": GameEnums.RankType.B,
	"MountainsCastle2": GameEnums.RankType.SS,
	"PlateauCastle1": GameEnums.RankType.A,
	"PlateauCastle2": GameEnums.RankType.SSS,
	"ForestCastle1": GameEnums.RankType.S,
	"ForestCastle2": GameEnums.RankType.C,
	"DesertCastle1": GameEnums.RankType.SS,
	"DesertCastle2": GameEnums.RankType.B,
	"IcefieldCastle1": GameEnums.RankType.SSS,
	"IcefieldCastle2": GameEnums.RankType.A,
}

## 城堡 id → 佔領後對應的根據地生產建築(GameEnums.BuildingType),決定產出哪種資源、
## 產量基準值,見 _monthly_yield_amount()。
const CASTLE_BUILDING_BY_ID: Dictionary = {
	"PlainsCastle1": GameEnums.BuildingType.LUMBER_MILL,
	"PlainsCastle2": GameEnums.BuildingType.MINE,
	"MountainsCastle1": GameEnums.BuildingType.CARAVAN,
	"MountainsCastle2": GameEnums.BuildingType.WORKSHOP,
	"PlateauCastle1": GameEnums.BuildingType.SCRIPTORIUM,
	"PlateauCastle2": GameEnums.BuildingType.FORBIDDEN_ALTAR,
	"ForestCastle1": GameEnums.BuildingType.QUARRY,
	"ForestCastle2": GameEnums.BuildingType.FARM,
	"DesertCastle1": GameEnums.BuildingType.BLACK_MARKET,
	"DesertCastle2": GameEnums.BuildingType.HUNTING_GROUND,
	"IcefieldCastle1": GameEnums.BuildingType.RESEARCH_INSTITUTE,
	"IcefieldCastle2": GameEnums.BuildingType.ALTAR,
}

## 城堡產出固定套用的建築等級基準(對應「約 3~4 等地量」的需求),不隨真正的根據地
## 建築等級變動,也不吃角色素質(城堡不用派人力),見 _monthly_yield_amount()。
const PRODUCTION_LEVEL := 4

## 需要原料的高階建築(QUARRY/MINE/BLACK_MARKET/SCRIPTORIUM/RESEARCH_INSTITUTE/
## FORBIDDEN_ALTAR,即 Building.fixed_recipe != null)城堡產出額外打折——城堡產出不模擬
## 原料鏈/不會真的消耗其他資源,用固定折扣代表「多工序產物量少很多」。
const RECIPE_BUILDING_PENALTY := 0.5

var conquered_ids: Dictionary = {}


func _ready() -> void:
	WorldTimeStore.controller.register_month_event(_on_month_passed)


func rank_for(castle_id: String) -> int:
	return CASTLE_RANK_BY_ID.get(castle_id, GameEnums.RankType.C)


func building_type_for(castle_id: String) -> int:
	return CASTLE_BUILDING_BY_ID.get(castle_id, -1)


func is_conquered(castle_id: String) -> bool:
	return conquered_ids.get(castle_id, false)


func conquer(castle_id: String) -> void:
	conquered_ids[castle_id] = true
	changed.emit()


func _find_building(building_type: int) -> Building:
	for building in BuildingLibrary.get_all():
		if building.type == building_type:
			return building
	return null


func _monthly_yield_amount(building: Building) -> int:
	var multiplier := BaseProduction.building_efficiency(PRODUCTION_LEVEL)
	if building.fixed_recipe != null:
		multiplier *= RECIPE_BUILDING_PENALTY
	return roundi(building.base_yield * multiplier)


## 這座城堡「本月產出」的資源類型與數量,供攻略後的管家聊天報告、月結算共用,結果是
## 固定值(不吃角色/建築等級),不需要另外存「上個月產出」快照。castle_id 不是已佔領
## 城堡時回傳 {}。
func monthly_yield_for(castle_id: String) -> Dictionary:
	if not is_conquered(castle_id):
		return {}
	var building := _find_building(building_type_for(castle_id))
	if building == null:
		return {}
	return {"resource_type": building.produces, "amount": _monthly_yield_amount(building)}


## 預覽「如果現在跨過月結算」各種資源的淨變動量,供 Scripts/UI/header_bar.gd 的「詳細」
## 面板整合進「本月+多少」預覽——算法跟 _on_month_passed() 一致,但不真的加值,純預覽。
func get_projected_monthly_delta() -> Dictionary:
	var delta: Dictionary = {}
	for castle_id in conquered_ids:
		var info := monthly_yield_for(castle_id)
		if info.is_empty():
			continue
		delta[info.resource_type] = delta.get(info.resource_type, 0) + info.amount
	return delta


func _on_month_passed() -> void:
	for castle_id in conquered_ids:
		var info := monthly_yield_for(castle_id)
		if info.is_empty():
			continue
		BaseResourceStore.add(info.resource_type, info.amount)


func to_save_data() -> Dictionary:
	return conquered_ids.duplicate()


func load_save_data(data: Dictionary) -> void:
	conquered_ids = data.duplicate()
	changed.emit()
