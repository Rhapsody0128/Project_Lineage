class_name BarracksTraining
extends RefCounted

## 兵營訓練天數/耗材表,依 Rank(F~SSS)查(見「根據地內政系統設計」文件六節)。傳授
## 新主動技能/訓練已學被動技能共用同一張表(方案 A:規則單純,不用維護兩張表)。天數
## 刻意跟建築升級曲線分開設計(3~70 天,比建築快很多)——這是角色個別可重複的培養行為,
## 不是建築等級,不該用相同的百日尺度。

const DAYS_BY_RANK: Array[int] = [3, 5, 8, 12, 18, 26, 36, 50, 70]

const COST_BY_RANK: Array[Dictionary] = [
	{GameEnums.ResourceType.WOOD: 20},
	{GameEnums.ResourceType.WOOD: 35, GameEnums.ResourceType.STONE: 15},
	{GameEnums.ResourceType.STONE: 40, GameEnums.ResourceType.ORE: 15},
	{GameEnums.ResourceType.STONE: 60, GameEnums.ResourceType.ORE: 30, GameEnums.ResourceType.CRAFT: 10},
	{GameEnums.ResourceType.ORE: 50, GameEnums.ResourceType.CRAFT: 25, GameEnums.ResourceType.GOLD: 60},
	{GameEnums.ResourceType.CRAFT: 45, GameEnums.ResourceType.GOLD: 120, GameEnums.ResourceType.BOOK: 30},
	{GameEnums.ResourceType.CRAFT: 70, GameEnums.ResourceType.GOLD: 220, GameEnums.ResourceType.BOOK: 60, GameEnums.ResourceType.RESEARCH: 20},
	{GameEnums.ResourceType.CRAFT: 100, GameEnums.ResourceType.GOLD: 380, GameEnums.ResourceType.RESEARCH: 45, GameEnums.ResourceType.FAITH: 30},
	{GameEnums.ResourceType.CRAFT: 150, GameEnums.ResourceType.GOLD: 600, GameEnums.ResourceType.RESEARCH: 80, GameEnums.ResourceType.FAITH: 60, GameEnums.ResourceType.CURSE: 20},
]


static func days_for_rank(rank: GameEnums.RankType) -> int:
	return DAYS_BY_RANK[clampi(rank, 0, DAYS_BY_RANK.size() - 1)]


static func cost_for_rank(rank: GameEnums.RankType) -> Dictionary:
	return COST_BY_RANK[clampi(rank, 0, COST_BY_RANK.size() - 1)]


## 角色是否已經知道這個技能——用 id 比對,不比對物件參照(SkillLibrary.build() 每次
## 呼叫都是全新實例,見該檔案)。
static func character_knows_skill(character: Character, skill: Skill) -> bool:
	for known in character.skill_list:
		if known.id == skill.id:
			return true
	return false
