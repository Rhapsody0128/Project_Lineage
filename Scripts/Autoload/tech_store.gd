extends Node

# =========================================================
# 已解鎖的科技節點(autoload,見 project.godot)。只存 TechNode.id 的集合,一次性永久
# 解鎖,不像 UltimateStore 那樣有次數概念——科技理應是永久投資。
#
# 解鎖條件只有兩個(見 TechNode 開頭註解):
#   A. 科學研究所等級 ≥ node.required_institute_level()
#   B. node.prerequisite_id 對應節點已解鎖(鏈首不需要)
# 不綁定任何其他建築。
#
# get_bonus()/get_multiplier() 是效果套用的唯一入口——BaseProduction、CombatResolver
# 等呼叫端只呼叫這兩個函式取得「所有已解鎖節點疊加後」的數值,不會各自去掃 TechLibrary。
# =========================================================

signal changed

var _unlocked_ids: Dictionary = {}


func is_unlocked(tech_id: String) -> bool:
	return _unlocked_ids.has(tech_id)


func can_unlock(node: TechNode) -> bool:
	if node == null or is_unlocked(node.id):
		return false
	if node.has_prerequisite() and not is_unlocked(node.prerequisite_id):
		return false
	if BaseBuildingProgressStore.get_level(GameEnums.BuildingType.RESEARCH_INSTITUTE) < node.required_institute_level():
		return false
	return BaseResourceStore.can_afford({GameEnums.ResourceType.RESEARCH: node.cost})


## 前置未解鎖/等級不足/科研不足/已解鎖都回傳 false 且不扣款。
func unlock(node: TechNode) -> bool:
	if not can_unlock(node):
		return false
	BaseResourceStore.spend({GameEnums.ResourceType.RESEARCH: node.cost})
	_unlocked_ids[node.id] = true
	changed.emit()
	return true


## 加總所有已解鎖節點裡屬於 effect_type 的 effect_value——同一機制鏈疊多層時,每層都是
## 「自己的增量」,加總結果就是玩家實際拿到的累計效果。沒有任何節點解鎖時回傳 0.0,呼叫端
## 可以直接拿來加/乘,不用另外判斷「有沒有解鎖科技」。
func get_bonus(effect_type: GameEnums.TechEffectType) -> float:
	var total := 0.0
	for tech_id in _unlocked_ids:
		var node := TechLibrary.get_by_id(tech_id)
		if node != null and node.effect_type == effect_type:
			total += node.effect_value
	return total


## 連乘版本,給「死亡機率曲線 ×0.9 ×0.8」這種疊乘效果用。沒有任何節點解鎖時回傳 1.0
## (不改變原值)。
func get_multiplier(effect_type: GameEnums.TechEffectType) -> float:
	var product := 1.0
	for tech_id in _unlocked_ids:
		var node := TechLibrary.get_by_id(tech_id)
		if node != null and node.effect_type == effect_type:
			product *= node.effect_value
	return product


## TechNode.id 是寫死的固定字串(見 tech_library.gd),不像 Skill/Ultimate 那樣是隨機
## UUID,可以直接存/讀。
func to_save_data() -> Array:
	var ids: Array = []
	for tech_id in _unlocked_ids:
		ids.append(tech_id)
	return ids


func load_save_data(data: Array) -> void:
	_unlocked_ids.clear()
	for tech_id in data:
		_unlocked_ids[tech_id] = true
	changed.emit()
