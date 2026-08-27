class_name SaveDataCodec
extends RefCounted

# =========================================================
# 存檔/讀檔(見 Scripts/Autoload/save_load_store.gd)用的資料轉換工具:JSON 只認識
# 字串/數字/布林/陣列/字典,這裡集中處理 Character/Party/PartyEditGrid 這幾個「有物件
# 參照(parent/mate/children、Character 陣列、Skill/Ultimate 物件)」的複雜類別怎麼攤平成
# 純資料字典、又怎麼從字典還原回物件。純數值的 autoload store(BaseResourceStore 等)
# 不需要用到這裡,自己在各自的 to_save_data()/load_save_data() 處理就好。
#
# 不放在 System/ 是因為這是存檔格式/UI 層的持久化基礎設施,不是戰鬥/角色規則本身
# (比照 CLAUDE.md「Scripts/:非 autoload、非 UI 元件的零散共用資料類別」的定位)。
#
# Skill.id/Ultimate.id 是執行期隨機 UUID(見 skill.gd/ultimate.gd 的 _init()),重開
# 遊戲後會變,不能拿來跨進程存檔比對——技能/奧義一律存「名稱」,讀檔時透過
# SkillController.get_by_name()/UltimateLibrary.get_by_name() 換回目前執行期唯一的那個
# 物件實體(不能自己 new 一個新的 Skill/Ultimate,那樣 action/resolve_action 這些
# Callable 綁定會是空的)。WorkshopRecipe.id/Tech.id 則是寫死的固定字串(見
# workshop_recipe_library.gd/tech_library.gd),可以直接存 id。
# =========================================================

## Character 是父母/配偶/子女互相參照的圖(parent/mate/children),兩階段還原:
## decode_character_base() 先建好角色本身的資料(不含關係),AllCharacterStore
## 讀完「全部」角色、建好 id → Character 的對照表後,再逐一呼叫 link_character_relations()
## 補上關係——關係另一端的角色不一定已經建好,必須等全部角色都存在才能連。
static func encode_character(character: Character) -> Dictionary:
	var trait_data: Array = []
	for character_trait in character.traits:
		trait_data.append({
			"name": character_trait.name,
			"description": character_trait.description,
			"polarity": character_trait.polarity,
			"stat_multiplier": character_trait.stat_multiplier,
			"is_aging": character_trait.is_aging,
		})

	var cells: Array = []
	for cell in character.battle_cost.cells:
		cells.append([cell.x, cell.y])

	var skill_names: Array = []
	for skill in character.skill_list:
		skill_names.append(skill.name)

	var parent_ids: Array = []
	for parent_character in character.parent:
		parent_ids.append(parent_character.id)

	var children_ids: Array = []
	for child_character in character.children:
		children_ids.append(child_character.id)

	return {
		"id": character.id,
		"name": character.name,
		"last_name": character.last_name,
		"age": character.age,
		"gender": character.gender,
		"face_path": character.face_path,
		"traits": trait_data,
		"potential": _encode_potential(character.potential),
		"bloodline_percentages": character.bloodline.percentages,
		"weapon": character.weapon,
		"skill_names": skill_names,
		"level": character.level_system.level,
		"exp": character.level_system.exp,
		"hp": character.hp,
		"battle_cost_cells": cells,
		"is_protagonist": character.is_protagonist,
		"is_pregnant": character.is_pregnant,
		"pregnancy_months": character.pregnancy_months,
		"postpartum_months_remaining": character.postpartum_months_remaining,
		"is_dead": character.is_dead,
		"parent_ids": parent_ids,
		"mate_id": character.mate.id if character.mate != null else "",
		"children_ids": children_ids,
	}


static func _encode_potential(potential: Potential) -> Dictionary:
	return {
		"strength": potential.strength,
		"vitality": potential.vitality,
		"agility": potential.agility,
		"dexterity": potential.dexterity,
		"intelligence": potential.intelligence,
		"mentality": potential.mentality,
		"strength_ratio": potential.strength_ratio,
		"vitality_ratio": potential.vitality_ratio,
		"agility_ratio": potential.agility_ratio,
		"dexterity_ratio": potential.dexterity_ratio,
		"intelligence_ratio": potential.intelligence_ratio,
		"mentality_ratio": potential.mentality_ratio,
	}


## 第一階段:建好角色本身(不含 parent/mate/children),id 沿用存檔裡的舊 id
## (Character._init() 內部會另外配一個新 UUID,建完要覆寫回去)。
static func decode_character_base(data: Dictionary) -> Character:
	var traits: Array[CharacterTrait] = []
	for trait_data in data.get("traits", []):
		var character_trait := CharacterTrait.new(trait_data["name"], trait_data["description"], int(trait_data["polarity"]))
		character_trait.stat_multiplier = float(trait_data.get("stat_multiplier", 1.0))
		character_trait.is_aging = trait_data.get("is_aging", false)
		traits.append(character_trait)

	var p: Dictionary = data["potential"]
	var potential := Potential.new(
		p["strength"], p["vitality"], p["agility"], p["dexterity"], p["intelligence"], p["mentality"],
		p["strength_ratio"], p["vitality_ratio"], p["agility_ratio"], p["dexterity_ratio"], p["intelligence_ratio"], p["mentality_ratio"]
	)

	var percentages: Array[float] = []
	percentages.assign(data["bloodline_percentages"])
	var bloodline := Bloodline.new(percentages)

	var skill_list: Array[Skill] = []
	for skill_name in data.get("skill_names", []):
		var skill := SkillController.get_by_name(skill_name)
		if skill != null:
			skill_list.append(skill)

	var cells: Array[Vector2i] = []
	for cell_data in data["battle_cost_cells"]:
		cells.append(Vector2i(int(cell_data[0]), int(cell_data[1])))
	var battle_cost := BattleCost.new(cells)

	var level_system := LevelSystem.new(int(data["level"]))
	level_system.exp = int(data.get("exp", 0))

	var character := Character.new(
		data["name"], data["last_name"], int(data["age"]), int(data["gender"]), data["face_path"],
		traits, potential, bloodline, int(data["weapon"]), skill_list, level_system, battle_cost
	)
	character.id = data["id"]
	character.hp = int(data["hp"])
	character.is_protagonist = data.get("is_protagonist", false)
	character.is_pregnant = data.get("is_pregnant", false)
	character.pregnancy_months = int(data.get("pregnancy_months", 0))
	character.postpartum_months_remaining = int(data.get("postpartum_months_remaining", 0))
	character.is_dead = data.get("is_dead", false)
	return character


## 第二階段:by_id 是這次讀檔全部角色的 id → Character 對照表,補上 parent/mate/children。
## 找不到的 id(理論上不會發生,存檔資料本來就是同一批角色互相參照)直接跳過。
static func link_character_relations(character: Character, data: Dictionary, by_id: Dictionary) -> void:
	var parents: Array[Character] = []
	for parent_id in data.get("parent_ids", []):
		if by_id.has(parent_id):
			parents.append(by_id[parent_id])
	character.parent = parents

	var mate_id: String = data.get("mate_id", "")
	if mate_id != "" and by_id.has(mate_id):
		character.mate = by_id[mate_id]

	var children: Array[Character] = []
	for child_id in data.get("children_ids", []):
		if by_id.has(child_id):
			children.append(by_id[child_id])
	character.children = children


## Party 只存角色 id(不重複存整份角色資料——角色本體已經在 AllCharacterStore 那份存好),
## 讀檔時靠呼叫端傳入的 by_id 換回實際 Character 參照。
static func encode_party(party: Party) -> Dictionary:
	if party == null:
		return {}

	var character_ids: Array = []
	for character in party.characteres:
		character_ids.append(character.id)

	var positions: Dictionary = {}
	for character in party.characteres:
		if party.has_battle_position(character):
			var cell := party.get_battle_position(character)
			positions[character.id] = [cell.x, cell.y]

	var ultimate_names: Array = []
	for ultimate in party.ultimates:
		ultimate_names.append(ultimate.name)

	return {
		"name": party.name,
		"leader_id": party.leader.id if party.leader != null else "",
		"character_ids": character_ids,
		"rank_type": party.rank_type,
		"ultimate_names": ultimate_names,
		"battle_cost_positions": positions,
	}


static func decode_party(data: Dictionary, by_id: Dictionary) -> Party:
	if data.is_empty():
		return null

	var characteres: Array[Character] = []
	for character_id in data.get("character_ids", []):
		if by_id.has(character_id):
			characteres.append(by_id[character_id])

	var leader: Character = by_id.get(data.get("leader_id", ""), null)
	var party := Party.new(data.get("name", "小隊"), characteres, leader)
	party.rank_type = int(data.get("rank_type", -1))

	var ultimates: Array[Ultimate] = []
	for ultimate_name in data.get("ultimate_names", []):
		var ultimate := UltimateLibrary.get_by_name(ultimate_name)
		if ultimate != null:
			ultimates.append(ultimate)
	party.ultimates = ultimates

	var positions: Dictionary = data.get("battle_cost_positions", {})
	for character_id in positions:
		if by_id.has(character_id):
			var cell_data: Array = positions[character_id]
			party.set_battle_position(by_id[character_id], Vector2i(int(cell_data[0]), int(cell_data[1])))

	return party


## PartyEditGrid 的站位其實跟 Party.battle_cost_positions 是同一份資料(見
## party_edit.gd 完成編輯時兩者一起寫入),所以不用另外存一份 anchor/shape——這裡直接
## 拿還原好的 party 重新 place() 一次即可,只需要額外存「解鎖格」跟「隊長」。
static func encode_party_grid(grid: PartyEditGrid) -> Dictionary:
	if grid == null:
		return {}

	var unlocked: Array = []
	for cell in grid.get_unlocked_cells():
		unlocked.append([cell.x, cell.y])

	var leader := grid.get_leader()
	return {
		"unlocked_cells": unlocked,
		"leader_id": leader.id if leader != null else "",
	}


static func decode_party_grid(data: Dictionary, party: Party, by_id: Dictionary) -> PartyEditGrid:
	if data.is_empty() or party == null:
		return null

	var grid := PartyEditGrid.new()

	var cells: Array[Vector2i] = []
	for cell_data in data.get("unlocked_cells", []):
		cells.append(Vector2i(int(cell_data[0]), int(cell_data[1])))
	grid.unlock_cells(cells)

	for character in party.characteres:
		if party.has_battle_position(character):
			grid.place(character, character.battle_cost.cells, party.get_battle_position(character))

	var leader_id: String = data.get("leader_id", "")
	if by_id.has(leader_id):
		grid.set_leader(by_id[leader_id])

	return grid


## BaseResourceStore/BaseBuildingProgressStore/BaseDispatchStore/NationFavorStore/
## BaseExchangeStore 共用:這幾個 store 都用 GameEnums 的 int enum 值當 Dictionary key,
## JSON 物件的 key 只能是字串,存檔時轉成字串、讀檔時轉回 int。value 是純資料
## (int/bool/Array[String]/Dictionary)時原封不動照抄,不需要另外處理。
static func int_keyed_to_str(dict: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in dict:
		result[str(key)] = dict[key]
	return result


static func str_keyed_to_int(dict: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in dict:
		result[int(key)] = dict[key]
	return result
