class_name BaseWarehouse
extends RefCounted

## 倉庫儲存上限查表(見「根據地內政系統設計」文件五節)。12 種資源依月產量分四個檔位,
## 檔位基礎容量(Lv0,未建倉庫時的露天堆放額度)× 倉庫等級對應倍率,四捨五入到 10。
## BaseResourceStore.add() 呼叫 get_capacity() 幫產出的資源封頂,倉庫只管儲存上限,
## 不影響生產/效率/交易。

## T1 大宗(木材/糧食/金錢)/T2 中量(毛皮/書本/信仰)/T3 少量(石材/鐵礦/贓物)/
## T4 稀有(製作工藝/科研/詛咒)——分級依據是各資源的月產量基準(見
## System/base/building/building_library.gd 12 棟生產建築的 base_yield)。
const TIER_BASE: Dictionary = {
	GameEnums.ResourceType.WOOD: 200,
	GameEnums.ResourceType.FOOD: 200,
	GameEnums.ResourceType.GOLD: 200,
	GameEnums.ResourceType.FUR: 150,
	GameEnums.ResourceType.BOOK: 150,
	GameEnums.ResourceType.FAITH: 150,
	GameEnums.ResourceType.STONE: 120,
	GameEnums.ResourceType.ORE: 120,
	GameEnums.ResourceType.CONTRABAND: 120,
	GameEnums.ResourceType.CRAFT: 80,
	GameEnums.ResourceType.RESEARCH: 80,
	GameEnums.ResourceType.CURSE: 80,
}

## index i = 倉庫 Lv i(index 0 = 未建倉庫的 Lv0)。
const LEVEL_MULTIPLIER: Array[float] = [1.0, 1.5, 2.0, 2.75, 3.5, 4.5, 5.5, 7.0, 9.0, 12.0]


static func get_capacity(resource_type: int, warehouse_level: int) -> int:
	var base: int = TIER_BASE.get(resource_type, 0)
	var multiplier := LEVEL_MULTIPLIER[clampi(warehouse_level, 0, LEVEL_MULTIPLIER.size() - 1)]
	return roundi(base * multiplier / 10.0) * 10
