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

## 出生時小孩不帶任何技能(見 InheritanceController.create_child()),之後靠這支函式
## 給「一般隨機生成角色」(CharacterController.get_random_character()/get_fixed_protagonist())
## 發初始技能組,FUNC 化方便未來「小孩慢慢學會技能」的流程也呼叫同一套抽選規則。固定給
## 1 個對應武器的主動技+1 個對應武器的被動技(保底,SkillLibraryWeaponPassive 每武器
## 固定恰好一支,不用跟通用被動搶名額),另外依血統評級加碼抽 1~2 個通用被動(A 級以上
## 額外把血統覺醒技併入抽選池,並不是加碼多抽),不吃 SkillCountDrawTable 那套「抽好幾個
## 武器/通用技能塞滿」的舊機制。
static func get_random_initial_skill_list(weapon: GameEnums.WeaponType, noble_rank: GameEnums.RankType, bloodline: Bloodline) -> Array[Skill]:
	var result: Array[Skill] = []

	var active_skill := _draw_active_skill(weapon, noble_rank)
	if active_skill != null:
		result.append(active_skill)

	var passive_count := 2 if noble_rank > GameEnums.RankType.A else 1
	result.append_array(_draw_passive_skills(weapon, noble_rank, bloodline, passive_count))

	return result

## 主動技:RANK 沿用跟 Bloodline/Potential 評級同一套「基準評級→實際評級」加權骰選
## (RankDrawTable.roll(),集中在血統評級附近、偶爾探高一階),再從對應武器+評級的主動技裡
## 抽一支——SkillLibraryWeapon 每武器每階固定恰好一支,理論上抽不到(找不到)的情況不會
## 發生,防禦性回傳 null 只是避免極端資料缺漏時整段崩潰。
static func _draw_active_skill(weapon: GameEnums.WeaponType, noble_rank: GameEnums.RankType) -> Skill:
	var active_rank: int = RankDrawTable.roll(noble_rank)
	var pool: Array[Skill] = []
	for skill in _skill_library:
		if skill.bind_weapon == weapon and skill.rank == active_rank and not skill.is_passive and skill.required_bloodline_nation == -1:
			pool.append(skill)
	if pool.is_empty():
		return null
	return Util.get_random_from_array(pool)

## 武器被動保底 1 支(SkillLibraryWeaponPassive 每武器固定恰好一支,直接取,不跟通用被動
## 一起抽——早期版本把它丟進同一個池子跟 18 支通用被動搶 1~2 個名額,機率低到形同虛設),
## 剩下 count 個名額改成跟主動技同一套規則:每個名額各自呼叫一次 RankDrawTable.roll()
## (舊版是「不看階級,通用被動整池均勻抽」,結果評級跟角色血統評級完全脫鉤,低評級角色也
## 能抽到 SSS 被動——已改掉,不是設計如此),只在骰出來的那個評級的通用被動裡抽,
## 不會超過 noble_rank。血統覺醒技(SkillLibraryBlood)不受這個評級篩選:它們的 `rank`
## 欄位統一填 F,不代表取得難度(取得門檻本來就是 required_bloodline_rank 決定,見
## SkillLibraryBlood 檔頭註解),所以 A 級以上(noble_rank > A)時,角色實際持有那條血統
## 的覺醒技(Bloodline.get_percentage() > 0,呼應 Character.can_use_skill() 的血統守門)
## 每個名額都併入候選池一起抽,不額外骰評級。同一個名額骰到的候選池若剛好抽完/為空
## (該評級只有 2 支通用被動,且都已被前一個名額抽走時可能發生),直接跳過該名額,
## 不強制往下一階退而求其次。
static func _draw_passive_skills(weapon: GameEnums.WeaponType, noble_rank: GameEnums.RankType, bloodline: Bloodline, count: int) -> Array[Skill]:
	var result: Array[Skill] = []
	for skill in _skill_library:
		if skill.is_passive and skill.bind_weapon == weapon:
			result.append(skill)
			break

	var generic_pool: Array[Skill] = []
	for skill in _skill_library:
		if skill.is_passive and skill.bind_weapon == GameEnums.NO_WEAPON_BINDING and skill.required_bloodline_nation == -1:
			generic_pool.append(skill)

	var blood_pool: Array[Skill] = []
	if noble_rank > GameEnums.RankType.A:
		for skill in _skill_library:
			if skill.required_bloodline_nation != -1 and bloodline.get_percentage(skill.required_bloodline_nation, skill.required_bloodline_rank) > 0.0:
				blood_pool.append(skill)

	var picked: Array[Skill] = []
	for i in range(count):
		var rolled_rank: int = RankDrawTable.roll(noble_rank)
		var pool: Array[Skill] = blood_pool.duplicate()
		for skill in generic_pool:
			if skill.rank == rolled_rank:
				pool.append(skill)
		for skill in picked:
			pool.erase(skill)
		if pool.is_empty():
			continue
		picked.append(Util.get_random_from_array(pool))

	result.append_array(picked)
	return result
