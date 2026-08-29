class_name SkillRankRule
extends RefCounted

## 技能的「有效 rank」——血統覺醒技(SkillLibraryBlood)內部 rank 統一填 F(見該檔案檔頭
## 註解,rank 不代表取得難度),但兵營傳授(BarracksTeachingRule)/隊長訓練
## (LeaderTrainingRule)這類「依 rank 判定年齡門檻/兵營等級上限」的場景要把血統技能當
## A 級技能看待,不能直接讀 skill.rank。
static func effective_rank(skill: Skill) -> int:
	if skill.required_bloodline_nation != -1:
		return GameEnums.RankType.A
	return skill.rank
