class_name MarriageQuotaRule
extends RefCounted

## 城鎮中心聯姻名額公式:比照 AgingRule 讀 BaseBuildingProgressStore.get_level() 的既有
## 慣例——城鎮中心(STRONGHOLD)每一級 +1 個聯姻名額(1 級=1 個,不是「蓋好城鎮中心
## 才有 1 個、之後每級再 +1」的另一條累加公式),0 級(未建造)沒有名額。實際「這一年
## 已經用掉幾個」是會變動的玩家資料,不放在這個 RefCounted 規則類別裡,見
## Scripts/Autoload/marriage_quota_store.gd 的 MarriageQuotaStore。
## 「婚姻禮制」科技線(TechEffectType.MARRIAGE_QUOTA_ADD)在城鎮中心等級上加值。
static func max_quota_per_year() -> int:
	var base := BaseBuildingProgressStore.get_level(GameEnums.BuildingType.STRONGHOLD)
	return base + int(TechStore.get_bonus(GameEnums.TechEffectType.MARRIAGE_QUOTA_ADD))
