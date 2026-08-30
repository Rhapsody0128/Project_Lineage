class_name NationRelation
extends RefCounted

## 國與國之間的邦交狀態/WarTension 查詢入口。實際資料在 NationRelationStore
## (autoload),這裡維持一層薄的 System/ 查詢介面,呼叫端(NationRelations UI 等)
## 透過這裡取用,不直接碰 autoload,比照 System/nation/ 其餘檔案的查表慣例。

static func get_status(nation_a: int, nation_b: int) -> int:
	return NationRelationStore.get_war_status(nation_a, nation_b)


static func get_tension(nation_a: int, nation_b: int) -> float:
	return NationRelationStore.get_war_tension(nation_a, nation_b)


static func get_exhaustion(nation_a: int, nation_b: int, for_nation: int) -> float:
	return NationRelationStore.get_war_exhaustion(nation_a, nation_b, for_nation)
