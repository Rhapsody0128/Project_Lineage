class_name BarracksTeachingRule
extends RefCounted

## 兵營「傳授」——師徒制,取代原本的自學訓練(BarracksTraining/BarracksTrainingStore 已
## 整個刪除)。立即生效,不消耗資源、不花時間,只受三個限制:師父一生只能傳授一次
## (Character.has_taught_skill)、師父年齡門檻(依 SkillRankRule.effective_rank() 查表,
## 血統覺醒技當 A 級技能看待)、兵營等級上限。

## 師父年齡門檻,索引為 SkillRankRule.effective_rank()(F~SSS),等差 -5。
const MIN_TEACHER_AGE_BY_RANK: Array[int] = [40, 45, 50, 55, 60, 65, 70, 75, 80]


static func min_teacher_age(skill: Skill) -> int:
	return MIN_TEACHER_AGE_BY_RANK[SkillRankRule.effective_rank(skill)]


## barracks_rank:BaseBuildingProgressStore.get_rank(BuildingType.BARRACKS)。
static func can_teach(master: Character, student: Character, skill: Skill, barracks_rank: int) -> bool:
	return teach_block_reasons(master, student, skill, barracks_rank).is_empty()


## 逐條列出這支技能現在不能傳授的原因(空陣列代表可以傳授)——UI 端(BarracksTeachPanel)
## 要把每一條卡住的規則個別顯示給玩家看,不是像 can_teach() 那樣只回傳單一 bool 疊成一句
## 含糊的「反灰」提示(見 CLAUDE.md 這次需求)。條件跟 can_teach() 完全對應,只是拆開各自
## 附上文字說明。
static func teach_block_reasons(master: Character, student: Character, skill: Skill, barracks_rank: int) -> Array[String]:
	var reasons: Array[String] = []
	if master == student:
		reasons.append("師父與學生不能是同一人")
	if master.has_taught_skill:
		reasons.append("師父一生只能傳授一次，已經用掉了")
	if not master.knows_skill(skill):
		reasons.append("師父尚未學會這個技能")
	var required_rank := SkillRankRule.effective_rank(skill)
	if required_rank > barracks_rank:
		reasons.append("兵營等級不足（需求：%s 級）" % GameEnums.rank_label(required_rank))
	var required_age := min_teacher_age(skill)
	if master.age < required_age:
		reasons.append("師父年齡不足（需求：%d 歲，目前：%d 歲）" % [required_age, master.age])
	if student.knows_skill(skill):
		reasons.append("學生已經學會這個技能")
	# 武器不符不擋傳授——只是學會後暫時打不出來(CharacterDetailView 的技能格本來就會
	# 反灰示意「學過但目前裝備打不出來」),不影響師徒傳授這個動作本身,故意只擋血統不符
	# (那是永久性的,武器之後可能換裝備解開,見 CLAUDE.md 這次需求)。
	if skill.required_bloodline_nation != -1:
		var percentage := student.bloodline.get_percentage(skill.required_bloodline_nation, skill.required_bloodline_rank)
		if percentage <= 0.0:
			reasons.append("學生血統不符，無法使用這個技能")
	return reasons


## 師父可傳授給指定學生的技能池,僅限師父 skill_list 裡符合 can_teach() 的技能。
static func teachable_skills(master: Character, student: Character, barracks_rank: int) -> Array[Skill]:
	var result: Array[Skill] = []
	for skill in master.skill_list:
		if can_teach(master, student, skill, barracks_rank):
			result.append(skill)
	return result
