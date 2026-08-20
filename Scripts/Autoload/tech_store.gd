extends Node

# =========================================================
# 已解鎖的科技(autoload,見 project.godot)。只存 Tech.id 的集合,一次性永久解鎖,
# 不像 UltimateStore 那樣有次數概念——科技理應是永久投資。
# =========================================================

signal changed

var _unlocked_ids: Dictionary = {}


func is_unlocked(tech_id: String) -> bool:
	return _unlocked_ids.has(tech_id)


func can_unlock(tech: Tech) -> bool:
	if is_unlocked(tech.id):
		return false
	if BaseBuildingProgressStore.get_level(GameEnums.BuildingType.RESEARCH_INSTITUTE) < TechLibrary.level_requirement(tech.tier):
		return false
	return BaseResourceStore.can_afford({GameEnums.ResourceType.RESEARCH: tech.cost})


## 門檻不足/科研不足/已解鎖都回傳 false 且不扣款。
func unlock(tech: Tech) -> bool:
	if not can_unlock(tech):
		return false
	BaseResourceStore.spend({GameEnums.ResourceType.RESEARCH: tech.cost})
	_unlocked_ids[tech.id] = true
	changed.emit()
	return true
