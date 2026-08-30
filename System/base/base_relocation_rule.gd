class_name BaseRelocationRule
extends RefCounted

## 根據地遷移規則:合法落點判斷(地形可通行/離城鎮夠遠)+ 花費資料,供
## Scenes/Map/world_inner.gd 選點時呼叫。花費的實際扣款(BaseResourceStore)是
## Scripts/Autoload 的 session 狀態,不在這裡碰,比照 CastleStore/NationFavorStore
## 的既有慣例——這裡只給 COST 常數,呼叫端自己 can_afford()/spend()。

## 比照建築成本量級(Scenes/Base/base_action_panel.gd 常見的木材/石材花費)。
const COST: Dictionary = {
	GameEnums.ResourceType.WOOD: 500,
	GameEnums.ResourceType.STONE: 500,
}


## 「輕裝遷徙」科技線(TechEffectType.RELOCATION_COST_SUB)在 COST 每一項上扣減,
## 下限 clamp 在 0。呼叫端(Scenes/Map/world_inner.gd 選點流程)一律讀這支函式,不要
## 直接讀 COST 常數。
static func cost() -> Dictionary:
	var reduction := TechStore.get_bonus(GameEnums.TechEffectType.RELOCATION_COST_SUB)
	var result: Dictionary = {}
	for resource_type in COST:
		result[resource_type] = maxi(COST[resource_type] - int(reduction), 0)
	return result

## 城鎮座標間距實際落在 1000~2000+ 之間(見 System/map/map_object.gd 的 get_all()),
## 800 大約是地圖尺寸(MapSystem.MAP_SIZE 8000x4500)的 1/10,足以避免根據地直接貼著
## 城鎮,又不會讓可選範圍過小。遊戲目前沒有獨立的「村莊」地點類型(只有
## GameEnums.MapObjectType 的 TOWN/BASE/CASTLE,見 map_object.gd 開頭註解),這裡的
## 「城鎮」判斷只比對 TOWN,不含 CASTLE。
const MIN_DISTANCE_TO_TOWN := 800.0


## 這個世界座標能不能當新根據地位置:回傳空字串代表合法,否則回傳給玩家看的理由文字。
## 不可通行(山岳鏤空/海面/地圖外,見 MapTerrainMask.is_walkable())或太靠近任一座城鎮
## 都不合法。
static func invalid_reason(pos: Vector2) -> String:
	if not MapTerrainMask.is_walkable(pos):
		return "此處無法通行,不能遷移根據地"
	for obj in MapObject.get_all():
		if obj.type != GameEnums.MapObjectType.TOWN:
			continue
		if obj.position.distance_to(pos) < MIN_DISTANCE_TO_TOWN:
			return "太靠近城鎮,不能遷移根據地"
	return ""
