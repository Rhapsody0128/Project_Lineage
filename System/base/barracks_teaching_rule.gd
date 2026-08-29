class_name BarracksTeachingRule
extends RefCounted

## 兵營「傳授」——師徒制,取代原本的自學訓練(BarracksTraining/BarracksTrainingStore 已
## 整個刪除)。立即生效,不消耗資源、不花時間,不限傳授次數(Character.taught_skill_count
## 只是累計次數供 UI 顯示,不構成限制),只受兩個限制:師父年齡門檻(依
## SkillRankRule.effective_rank() 查表,血統覺醒技當 A 級技能看待)、兵營等級上限。

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
	# 武器/血統都不擋傳授。被動技能傳授後不管手持什麼武器都能直接觸發（Character.
	# can_use_skill() 對被動技能不做武器守門，武器主動技才要求相符武器，見該函式註解）；
	# 血統覺醒技則永久打不出來（CharacterDetailView 的技能格會反灰示意「學過但目前用不
	# 出來」），不影響師徒傳授這個動作本身。血統覺醒技可以傳授給不同血統的角色，即使該角色
	# 可能永遠無法實際施放（見 CLAUDE.md 這次需求）。
	return reasons


## 師父可傳授給指定學生的技能池,僅限師父 skill_list 裡符合 can_teach() 的技能。
static func teachable_skills(master: Character, student: Character, barracks_rank: int) -> Array[Skill]:
	var result: Array[Skill] = []
	for skill in master.skill_list:
		if can_teach(master, student, skill, barracks_rank):
			result.append(skill)
	return result
