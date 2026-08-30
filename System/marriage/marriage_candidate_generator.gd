class_name MarriageCandidateGenerator
extends RefCounted

## 城鎮中心聯姻流程:寄信去某個國家後,該國回信的候選人生成規則。評級基準是「提案角色自身的
## 身分爵位」(Character.title_rank)疊加城鎮中心等級加成(每 4 級 +1 級,向下取整),身分
## 愈高、城鎮中心愈高級、候選人評級基準愈高、bloodline 愈容易抽到高血(見
## BloodlineController.get_random_bloodline() 的 noble_steps = rank_type)——取代舊版依
## 國家好感度(NationFavorRank.rank_for_favor())換算的作法,好感度不再影響候選人評級。
## 疊加後的基準值 clamp 在 RankDrawTable.MAX_BASE_RANK(而不是提早封頂在
## GameEnums.RankType.SSS),才能吃到 RankDrawTable.TABLE 特地留給「自身 RANK 數量 + N」
## 情境的 SSS+1~+5 那幾列,城鎮中心衝到夠高等級時候選人評級仍能持續往上探。性別固定跟
## proposer 相反(呼應 MarriageRule.can_propose() 的性別互斥條件),國家固定是玩家指定的
## nation,兩者都直接傳給 CharacterController.get_random_character()。
const CANDIDATE_COUNT := 3

## 城鎮中心每滿 4 級,候選人評級基準 +1 級。
const STRONGHOLD_LEVEL_PER_RANK_BONUS := 4

static func generate_candidates(proposer: Character, nation: int, count: int = CANDIDATE_COUNT) -> Array[Character]:
	var stronghold_level := BaseBuildingProgressStore.get_level(GameEnums.BuildingType.STRONGHOLD)
	var rank := mini(proposer.title_rank + stronghold_level / STRONGHOLD_LEVEL_PER_RANK_BONUS, RankDrawTable.MAX_BASE_RANK)
	var opposite_gender := GameEnums.Gender.FEMALE if proposer.gender == GameEnums.Gender.MALE else GameEnums.Gender.MALE

	var candidates: Array[Character] = []
	for i in range(count):
		candidates.append(CharacterController.get_random_character(rank, nation, opposite_gender))
	return candidates
