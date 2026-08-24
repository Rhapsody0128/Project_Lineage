class_name MarriageCandidateGenerator
extends RefCounted

## 城鎮中心聯姻流程:寄信去某個國家後,該國回信的候選人生成規則。評級依「玩家對該國的
## 好感度」換算(NationFavorRank.rank_for_favor()),好感度愈高,候選人評級基準愈高、
## bloodline 愈容易抽到高血(見 BloodlineController.get_random_bloodline() 的
## noble_steps = rank_type),跟 TavernStore._resolve_base_rank() 同一套慣例。性別固定跟
## proposer 相反(呼應 MarriageRule.can_propose() 的性別互斥條件),國家固定是玩家指定的
## nation,兩者都直接傳給 CharacterController.get_random_character()。
const CANDIDATE_COUNT := 3

static func generate_candidates(proposer: Character, nation: int, count: int = CANDIDATE_COUNT) -> Array[Character]:
	var rank := NationFavorRank.rank_for_favor(NationFavorStore.get_favor(nation))
	var opposite_gender := GameEnums.Gender.FEMALE if proposer.gender == GameEnums.Gender.MALE else GameEnums.Gender.MALE

	var candidates: Array[Character] = []
	for i in range(count):
		candidates.append(CharacterController.get_random_character(rank, nation, opposite_gender))
	return candidates
