class_name SkillIdentity
extends RefCounted

## 技能穩定 id 生成:取代 Skill._init() 隨機 UUID(見 skill.gd,重開遊戲會變,只能靠名稱
## 字串還原存檔/比對身份,見 SkillController.get_by_name() 舊版註解)。這裡改成依技能自身
## 已有的資料欄位(武器/評級/血統國家)或所在 library 檔案裡的固定順序組出 id,只要各
## SkillLibraryXxx 的 build()/_xxx_skills() 不重新排列/插入既有技能,id 就能跨執行期、
## 跨存檔保持穩定,不受技能改名或在地化影響。呼叫端(各 SkillLibraryXxx 尾端)一律在
## return 前呼叫這裡對應的 stamp_*(),不要自己手動拼字串。

## 武器主動技(SkillLibraryWeapon):同一武器同一評級恰好一支,id 直接查 skill 自身的
## bind_weapon/rank 欄位,不吃陣列位置。
static func stamp_weapon_active(skills: Array[Skill]) -> Array[Skill]:
	for skill in skills:
		skill.id = "W_%s_%s" % [GameEnums.WeaponType.keys()[skill.bind_weapon], GameEnums.RankType.keys()[skill.rank]]
	return skills

## 武器被動技(SkillLibraryWeaponPassive):每武器固定一支,不分評級,id 只查 bind_weapon。
static func stamp_weapon_passive(skills: Array[Skill]) -> Array[Skill]:
	for skill in skills:
		skill.id = "WP_%s" % GameEnums.WeaponType.keys()[skill.bind_weapon]
	return skills

## 通用被動(SkillLibraryPassive):同一評級有 2 支,沒有其他欄位可區分,只能靠陣列位置——
## 這個檔案的 18 支是固定攤平寫死的清單,不會被其他來源插入。
static func stamp_generic_passive(skills: Array[Skill]) -> Array[Skill]:
	for i in skills.size():
		skills[i].id = "P_%02d" % i
	return skills

## 大將技(SkillLibraryLeader):_support_skills()/_debuff_skills() 各 9 階恰好一支,
## id 查 rank 欄位 + 呼叫端傳入的分類前綴(L_SUPPORT/L_DEBUFF)。
static func stamp_leader(skills: Array[Skill], prefix: String) -> Array[Skill]:
	for skill in skills:
		skill.id = "%s_%s" % [prefix, GameEnums.RankType.keys()[skill.rank]]
	return skills

## 血統覺醒技(SkillLibraryBlood):同一血統 4 支 rank 統一填同一個值,沒有其他欄位可區分,
## 靠陣列位置(呼叫端一律傳自己血統的 _xxx_skills() 內部固定順序)。
static func stamp_blood(skills: Array[Skill], nation: GameEnums.BloodlineNation) -> Array[Skill]:
	for i in skills.size():
		skills[i].id = "B_%s_%02d" % [GameEnums.BloodlineNation.keys()[nation], i]
	return skills
