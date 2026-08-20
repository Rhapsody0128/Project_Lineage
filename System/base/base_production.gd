class_name BaseProduction
extends RefCounted

## 根據地生產類建築的每月產出公式:Base × 建築效率(依等級查表)× 角色效率(依素質開
## 根號,見 character_efficiency())。一棟建築可以同時派多位角色(容量見
## BaseBuildingProgressStore.get_max_workers()),逐一計算後加總即為整棟建築當月產出。
## 詳細設計依據見「根據地經濟藍圖」設計文件(01 節生產公式)。

## 建築等級效率,index 0 對應 Lv1,index 8 對應 Lv9——是查表,不是連續公式,漲幅逐級
## 加大(後期一級抵前期兩三級)。
const BUILDING_EFFICIENCY: Array[float] = [1.00, 1.10, 1.20, 1.35, 1.50, 1.70, 1.90, 2.15, 2.40]


## 角色屬性 0~200(理論上限),0 也有 50% 底薪、200 封頂 150%,開根號讓漲幅前段快、
## 後段慢,鼓勵把角色分散派到不同建築而不是全部堆一個屬性怪物身上。
static func character_efficiency(attribute_value: float) -> float:
	return 0.5 + sqrt(attribute_value / 200.0)


static func building_efficiency(level: int) -> float:
	return BUILDING_EFFICIENCY[clampi(level, 1, BUILDING_EFFICIENCY.size()) - 1]


## 回傳未四捨五入的浮點數,交給 compute_monthly_yield() 加總完再統一取整,避免逐人
## 四捨五入的誤差累積。
static func monthly_yield_for_worker(building: Building, character: Character, level: int) -> float:
	var attribute_value := character.get_potential(building.potential_type)
	return building.base_yield * building_efficiency(level) * character_efficiency(attribute_value)


static func compute_monthly_yield(building: Building, characters: Array[Character], level: int) -> int:
	var total := 0.0
	for character in characters:
		total += monthly_yield_for_worker(building, character, level)
	return roundi(total)
