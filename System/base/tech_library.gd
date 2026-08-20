class_name TechLibrary
extends RefCounted

## 五大科技分類,各三個門檻(見「根據地內政系統設計」文件八節)——科學研究所 Lv3/Lv6/Lv9
## 依序解鎖 tier 1/2/3,科研消耗 100/300/700,一次性永久解鎖(不像奧義是消耗品)。每格
## 只給百分比加成,不取代任何建築本身的功能。
##
## 這 15 格效果目前都還沒接程式邏輯,只有解鎖狀態的追蹤(見 Scripts/Autoload/
## tech_store.gd)——實際掛鉤(升級耗材-10%、移動速度+10%等)是後續工程項目,角色培養
## 科技的「屬性成長上限+10」尤其需要 System/inheritance/inheritance_constants.gd 的
## POTENTIAL_STAT_MAX 配合開放上限,工程量最大,建議放最後做。

const TIER_LEVEL_REQUIREMENT: Array[int] = [3, 6, 9]
const TIER_COST: Array[int] = [100, 300, 700]


static func get_all() -> Array[Tech]:
	return [
		Tech.new("econ_1", "經濟科技", "商隊效率", "商隊站/黑市兌換效率 +10%", 1, TIER_COST[0]),
		Tech.new("econ_2", "經濟科技", "倉儲擴建", "倉庫容量 +15%", 2, TIER_COST[1]),
		Tech.new("econ_3", "經濟科技", "產業革新", "全生產建築月產出 +10%", 3, TIER_COST[2]),
		Tech.new("build_1", "建築科技", "工程加速", "全建築升級時間 -10%", 1, TIER_COST[0]),
		Tech.new("build_2", "建築科技", "資材節約", "全建築升級耗材 -10%", 2, TIER_COST[1]),
		Tech.new("build_3", "建築科技", "速成建設", "建造(0→1)天數減半", 3, TIER_COST[2]),
		Tech.new("military_1", "軍事科技", "特訓精簡", "兵營訓練時間 -15%", 1, TIER_COST[0]),
		Tech.new("military_2", "軍事科技", "強健體魄", "角色戰場 HP 上限 +5%", 2, TIER_COST[1]),
		Tech.new("military_3", "軍事科技", "軍需改革", "兵營訓練耗材 -20%", 3, TIER_COST[2]),
		Tech.new("growth_1", "角色培養科技", "勤勉獎勵", "派駐經驗 +20%", 1, TIER_COST[0]),
		Tech.new("growth_2", "角色培養科技", "戰陣歷練", "戰鬥經驗 +10%", 2, TIER_COST[1]),
		Tech.new("growth_3", "角色培養科技", "潛能開發", "角色屬性成長上限 +10(200→220)", 3, TIER_COST[2]),
		Tech.new("explore_1", "探索科技", "輕裝疾行", "大地圖移動速度 +10%", 1, TIER_COST[0]),
		Tech.new("explore_2", "探索科技", "情報網絡", "遊蕩敵人/城門守衛掉落 +15%", 2, TIER_COST[1]),
		Tech.new("explore_3", "探索科技", "命運之輪", "世界事件觸發率 +10%", 3, TIER_COST[2]),
	]


static func get_by_id(id: String) -> Tech:
	for tech in get_all():
		if tech.id == id:
			return tech
	return null


static func level_requirement(tier: int) -> int:
	return TIER_LEVEL_REQUIREMENT[clampi(tier, 1, 3) - 1]
