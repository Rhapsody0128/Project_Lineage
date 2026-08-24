extends Node

# =========================================================
# 城鎮中心聯姻名額(autoload,見 project.godot)——這一年已經用掉幾個名額的玩家資料,不是
# 規則邏輯,規則邏輯(名額公式)在 System/marriage/marriage_quota_rule.gd 的
# MarriageQuotaRule,跟 BaseBuildingProgressStore/AgingRule 同一套慣例。
#
# 「升級不重製名額」:used_this_year 只在跨年時歸零(見 _on_year_passed()),城鎮中心
# 升級只會改變 MarriageQuotaRule.max_quota_per_year() 算出來的上限,不會去動
# used_this_year 本身——所以升級當下已用掉的名額不會被清空重來,只是上限多了幾個。
# =========================================================

var used_this_year: int = 0


func _ready() -> void:
	WorldTimeStore.controller.register_year_event(_on_year_passed)


func remaining() -> int:
	return max(0, MarriageQuotaRule.max_quota_per_year() - used_this_year)


func consume() -> void:
	used_this_year += 1


func _on_year_passed() -> void:
	used_this_year = 0


func to_save_data() -> Dictionary:
	return {"used_this_year": used_this_year}


func load_save_data(data: Dictionary) -> void:
	used_this_year = data.get("used_this_year", 0)
