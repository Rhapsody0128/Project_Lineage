class_name LeaderTrainingRule
extends RefCounted

## 兵營「隊長訓練」——花金錢立即學會一支隊長技能(SkillLibraryLeader 的 18 支,增益/減益都
## 算),不限定角色是否為現任隊長:隊長技能誰都能學,只有戰鬥中 BattleCharacter.is_leader
## 才會被納入行動候選(見 System/battle/battle_ai.gd),兵營端不重複擋這件事。

## 金幣花費,索引為 SkillRankRule.effective_rank()(F~SSS),越高階越貴(假設數值,之後可調)。
const GOLD_COST_BY_RANK: Array[int] = [50, 100, 180, 300, 460, 700, 1050, 1600, 2400]


static func cost_for_skill(skill: Skill) -> int:
	return GOLD_COST_BY_RANK[SkillRankRule.effective_rank(skill)]


static func can_learn(character: Character, skill: Skill, barracks_rank: int) -> bool:
	if not skill.is_leader_skill:
		return false
	if SkillRankRule.effective_rank(skill) > barracks_rank:
		return false
	return not character.knows_skill(skill)
