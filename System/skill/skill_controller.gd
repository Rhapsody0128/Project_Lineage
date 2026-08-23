class_name SkillController
extends RefCounted

static var _skill_library: Array[Skill] = SkillLibrary.build()

static func get_skill_list() -> Array[Skill]:
	return _skill_library

static func get_skill(skill_index: int) -> Skill:
	return _skill_library[skill_index]

## 依名稱找技能:Skill.id 是隨機 UUID、重開遊戲會變(見 skill.gd _init()),存檔/讀檔
## (Scripts/Autoload/save_load_store.gd)要還原角色技能表只能靠名稱比對——技能名稱在
## SkillLibrary 裡本來就唯一,找不到回傳 null(技能改名/移除時讀舊存檔會遺漏該技能,
## 呼叫端自行過濾 null)。
static func get_by_name(skill_name: String) -> Skill:
	for skill in _skill_library:
		if skill.name == skill_name:
			return skill
	return null

static func get_skill_list_by_rank(skill_rank: GameEnums.RankType) -> Array[Skill]:
	var result: Array[Skill] = []
	for skill in _skill_library:
		if skill.rank == skill_rank:
			result.append(skill)
	return result

static func get_random_skill_list() -> Array[Skill]:
	if _skill_library.is_empty():
		return []
	var random_skill: Skill = _skill_library[Util.get_random_int(0, _skill_library.size())]
	return [random_skill]

static func get_random_skill_list_by_rank(skill_rank: GameEnums.RankType) -> Array[Skill]:
	var skill_list := get_skill_list_by_rank(skill_rank)
	if skill_list.is_empty():
		return []
	var random_skill: Skill = skill_list[Util.get_random_int(0, skill_list.size())]
	return [random_skill]

## 一個角色最多能持有的技能數——不是每個角色都要把全部「武器綁定+無綁定」技能塞滿,
## 避免技能欄/AI 骰選池被撐得過大。
const MAX_SKILLS_PER_CHARACTER := 4

## 該武器能用的技能:bind_weapon 相符,或技能沒有綁定武器(NO_WEAPON_BINDING,任何武器都能用)。
## target_count 是實際要抽的技能數(1~MAX_SKILLS_PER_CHARACTER,呼叫端多半傳
## SkillCountDrawTable.roll() 依血統評級骰出的值,不填則沿用舊行為抽滿上限)——優先保留這把
## 武器「專屬綁定」的技能(至少要有東西能打),其餘名額(含無綁定的被動/LEADER 技能)隨機從
## 剩下的裡面抽,不會每次都固定同一批,技能池本身不重複故結果不會重複。
static func get_skill_list_by_weapon(weapon_type: GameEnums.WeaponType, target_count: int = MAX_SKILLS_PER_CHARACTER) -> Array[Skill]:
	var clamped_count := clampi(target_count, 1, MAX_SKILLS_PER_CHARACTER)
	var bound: Array[Skill] = []
	var unbound: Array[Skill] = []
	for skill in _skill_library:
		if skill.bind_weapon == weapon_type:
			bound.append(skill)
		elif skill.bind_weapon == GameEnums.NO_WEAPON_BINDING:
			unbound.append(skill)

	var result: Array[Skill] = bound.duplicate()
	unbound.shuffle()
	for skill in unbound:
		if result.size() >= clamped_count:
			break
		result.append(skill)

	# 保險:萬一單一武器專屬技能本身就超過骰出的數量,還是要夾住上限(至少留 1 個能打)。
	if result.size() > clamped_count:
		result.shuffle()
		result = result.slice(0, clamped_count)

	return result

static func get_random_skill_list_by_weapon(weapon_type: GameEnums.WeaponType) -> Array[Skill]:
	var skill_list := get_skill_list_by_weapon(weapon_type)
	if skill_list.is_empty():
		return []
	var random_skill: Skill = skill_list[Util.get_random_int(0, skill_list.size())]
	return [random_skill]
