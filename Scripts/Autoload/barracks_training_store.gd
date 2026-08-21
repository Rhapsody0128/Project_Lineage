extends Node

# =========================================================
# 兵營訓練中的角色(autoload,見 project.godot)。character_id -> {skill: Skill,
# days_remaining: int}。角色訓練期間視同派駐兵營,不能出戰/在其他建築工作——沿用
# BaseDispatchStore.is_character_dispatched() 同一套佔用判斷,訓練開始前先檢查那邊
# 沒有指派,但不會真的寫進 BaseDispatchStore(兵營不是生產類建築,沒有工作格容量概念,
# 這裡自己独立管理訓練中名單)。
#
# _ready() 向 WorldTimeStore.controller 註冊每日結算,跟 BaseBuildingProgressStore 的
# 建造/升級倒數是同一種「天數」週期,各自獨立註冊。
# =========================================================

signal changed

var _training: Dictionary = {}


func _ready() -> void:
	WorldTimeStore.controller.register_day_event(_on_day_passed)


func is_training(character_id: String) -> bool:
	return _training.has(character_id)


func get_days_remaining(character_id: String) -> int:
	return _training.get(character_id, {}).get("days_remaining", 0)


func get_skill(character_id: String) -> Skill:
	return _training.get(character_id, {}).get("skill")


func get_trainees() -> Array[String]:
	var ids: Array[String] = []
	ids.assign(_training.keys())
	return ids


## 角色已在受訓/派駐其他建築、已經學會這個技能、資材不足都回傳 false 且不扣款。
func start_training(character: Character, skill: Skill) -> bool:
	if is_training(character.id) or BaseDispatchStore.is_character_dispatched(character.id):
		return false
	if BarracksTraining.character_knows_skill(character, skill):
		return false
	var cost := BarracksTraining.cost_for_rank(skill.rank)
	if not BaseResourceStore.can_afford(cost):
		return false
	BaseResourceStore.spend(cost)
	_training[character.id] = {"skill": skill, "days_remaining": BarracksTraining.days_for_rank(skill.rank)}
	changed.emit()
	return true


## Skill.id 是執行期隨機 UUID(見 skill.gd _init()),重開遊戲會變,改用名稱當還原依據
## (技能名稱在 SkillLibrary 裡本來就唯一,見 skill_controller.gd get_by_name())。
func to_save_data() -> Dictionary:
	var result: Dictionary = {}
	for character_id in _training:
		var entry: Dictionary = _training[character_id]
		var skill: Skill = entry["skill"]
		result[character_id] = {"skill_name": skill.name, "days_remaining": entry["days_remaining"]}
	return result


func load_save_data(data: Dictionary) -> void:
	_training.clear()
	for character_id in data:
		var entry: Dictionary = data[character_id]
		var skill := SkillController.get_by_name(entry.get("skill_name", ""))
		if skill != null:
			_training[character_id] = {"skill": skill, "days_remaining": int(entry.get("days_remaining", 0))}
	changed.emit()


func _on_day_passed() -> void:
	for character_id in _training.keys():
		var entry: Dictionary = _training[character_id]
		entry["days_remaining"] -= 1
		if entry["days_remaining"] <= 0:
			var character := BaseDispatchStore.find_character(character_id)
			if character != null:
				character.skill_list.append(entry["skill"])
				NewsController.post("%s 學會了技能「%s」。" % [character.full_name, entry["skill"].name])
			_training.erase(character_id)
			changed.emit()
		else:
			_training[character_id] = entry
