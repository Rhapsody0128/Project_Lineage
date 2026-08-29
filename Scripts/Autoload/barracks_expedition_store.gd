extends Node

# =========================================================
# 兵營「歷練」中的角色(autoload,見 project.godot),取代原本的 BarracksTrainingStore
# (自學訓練已被「傳授」完全取代)。character_id -> {days_remaining: int} 派出中;
# character_id -> {skills: Array[Skill], exp: int} 已歸來待玩家確認——固定跑
# WorldTime.DAYS_PER_YEAR 天,結算(抽技能+經驗)在天數歸零當下就算好,但要玩家自己按
# collect() 才會真正發放獎勵、回到可操作隊伍(比照使用者需求「回來之後要自己按他才會回到
# 可操作隊伍」)。臨時召回(recall())不結算任何獎勵,直接清除紀錄。
#
# _ready() 向 WorldTimeStore.controller 註冊每日結算,跟 BaseBuildingProgressStore 的
# 建造/升級倒數是同一種「天數」週期,各自獨立註冊。
# =========================================================

signal changed

var _expeditions: Dictionary = {}
var _completed: Dictionary = {}


func _ready() -> void:
	WorldTimeStore.controller.register_day_event(_on_day_passed)


func capacity() -> int:
	return BaseBuildingProgressStore.get_level(GameEnums.BuildingType.BARRACKS)


func is_on_expedition(character_id: String) -> bool:
	return _expeditions.has(character_id)


func is_awaiting_collection(character_id: String) -> bool:
	return _completed.has(character_id)


func get_days_remaining(character_id: String) -> int:
	return _expeditions.get(character_id, {}).get("days_remaining", 0)


func get_expedition_members() -> Array[String]:
	var ids: Array[String] = []
	ids.assign(_expeditions.keys())
	return ids


func get_completed_members() -> Array[String]:
	var ids: Array[String] = []
	ids.assign(_completed.keys())
	return ids


## 名額已滿/角色已在歷練中或待確認/已派駐其他建築/小隊隊長都回傳 false。小隊裡的非隊長
## 成員送去歷練會自動移出小隊(寫法比照 BaseDispatchStore.dispatch()——歷練是「離開一整年」,
## 不能人還掛在小隊裡卻同時歷練中)。
func send(character: Character) -> bool:
	if _expeditions.size() >= capacity():
		return false
	if is_on_expedition(character.id) or is_awaiting_collection(character.id):
		return false
	if BaseDispatchStore.is_character_dispatched(character.id):
		return false
	if PartyStore.party != null and PartyStore.party.characteres.has(character):
		if PartyStore.party.leader == character:
			return false
		if PartyStore.grid != null:
			PartyStore.grid.remove(character)
		PartyStore.party.characteres.erase(character)
		PartyStore.party.battle_cost_positions.erase(character)
	_expeditions[character.id] = {"days_remaining": WorldTime.DAYS_PER_YEAR}
	changed.emit()
	return true


## 臨時召回:不結算任何獎勵,直接清除紀錄,角色立即恢復可用。
func recall(character_id: String) -> void:
	if _expeditions.erase(character_id):
		changed.emit()


## 唯讀,不異動狀態——呼叫端(BarracksExpeditionPanel)收成時要先把這些技能逐一跑過
## SkillLearnFlow(技能滿了要跳替換/放棄彈窗,可能連續彈好幾次),都處理完才呼叫
## finalize_collect()。
func get_completed_skills(character_id: String) -> Array[Skill]:
	var skills: Array[Skill] = []
	skills.assign(_completed.get(character_id, {}).get("skills", []))
	return skills


## 技能都處理完(不論學會/放棄)之後呼叫:發經驗、清空待確認紀錄、發 NEWS。不再處理技能
## ——技能改由呼叫端先跑完 SkillLearnFlow 才呼叫這裡。
func finalize_collect(character_id: String) -> void:
	if not _completed.has(character_id):
		return
	var character := BaseDispatchStore.find_character(character_id)
	var entry: Dictionary = _completed[character_id]
	if character != null:
		character.gain_exp(int(entry["exp"]))
		NewsController.post("%s 歷練歸來。" % character.full_name, GameEnums.NewsCategory.DAILY)
	_completed.erase(character_id)
	changed.emit()


func _on_day_passed() -> void:
	var any_changed := false
	for character_id in _expeditions.keys():
		var entry: Dictionary = _expeditions[character_id]
		entry["days_remaining"] -= 1
		if entry["days_remaining"] <= 0:
			_completed[character_id] = _roll_result(character_id)
			_expeditions.erase(character_id)
		else:
			_expeditions[character_id] = entry
		any_changed = true
	if any_changed:
		changed.emit()


## 技能池比照傳授的 rank cap 概念,用兵營等級當上限,randi_range(1,2) 次不重複抽取角色
## 還不會、且能使用(武器/血統相符)的技能。經驗值固定給 BattleReward.exp_for_expedition()。
## 偶遇事件特性:trait 機制目前未接(見 CLAUDE.md),這裡不實作,之後特性系統完善時
## 從這裡補掛勾點。
func _roll_result(character_id: String) -> Dictionary:
	var character := BaseDispatchStore.find_character(character_id)
	var rank_cap := BaseBuildingProgressStore.get_rank(GameEnums.BuildingType.BARRACKS)
	var skills: Array[Skill] = []
	var exp := BattleReward.exp_for_expedition(rank_cap)
	if character == null:
		return {"skills": skills, "exp": exp}

	var pool: Array[Skill] = []
	for skill in SkillLibrary.build():
		if SkillRankRule.effective_rank(skill) <= rank_cap and character.can_use_skill(skill) and not character.knows_skill(skill):
			pool.append(skill)

	var draw_count := mini(randi_range(1, 2), pool.size())
	for i in range(draw_count):
		var skill: Skill = Util.get_random_from_array(pool)
		pool.erase(skill)
		skills.append(skill)

	return {"skills": skills, "exp": exp}


## Skill.id 是執行期隨機 UUID(見 skill.gd _init()),重開遊戲會變,改用名稱當還原依據
## (技能名稱在 SkillLibrary 裡本來就唯一,見 skill_controller.gd get_by_name())。
func to_save_data() -> Dictionary:
	var expeditions_data: Dictionary = {}
	for character_id in _expeditions:
		expeditions_data[character_id] = {"days_remaining": _expeditions[character_id]["days_remaining"]}

	var completed_data: Dictionary = {}
	for character_id in _completed:
		var entry: Dictionary = _completed[character_id]
		var skill_names: Array = []
		for skill in entry["skills"]:
			skill_names.append(skill.name)
		completed_data[character_id] = {"skill_names": skill_names, "exp": entry["exp"]}

	return {"expeditions": expeditions_data, "completed": completed_data}


func load_save_data(data: Dictionary) -> void:
	_expeditions.clear()
	for character_id in data.get("expeditions", {}):
		var entry: Dictionary = data["expeditions"][character_id]
		_expeditions[character_id] = {"days_remaining": int(entry.get("days_remaining", 0))}

	_completed.clear()
	for character_id in data.get("completed", {}):
		var entry: Dictionary = data["completed"][character_id]
		var skills: Array[Skill] = []
		for skill_name in entry.get("skill_names", []):
			var skill := SkillController.get_by_name(skill_name)
			if skill != null:
				skills.append(skill)
		_completed[character_id] = {"skills": skills, "exp": int(entry.get("exp", 0))}

	changed.emit()
