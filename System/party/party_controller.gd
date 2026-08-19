class_name PartyController
extends RefCounted

## 除錯用:強制全部角色使用同一種武器,方便單獨測試某個武器的技能表現。
## 預設 -1 代表關閉(維持 CharacterController.RANDOM_WEAPON_POOL 的正常隨機),
## 要測試特定武器時把這裡改成想測的 GameEnums.WeaponType 即可,不要動 get_random_party()
## 本體邏輯。
const DEBUG_FORCE_WEAPON: int = -1

## 難度曲線調參區:依 GameEnums.RankType(F~SSS,9 級)決定「隨機生成小隊」的平均等級與
## 人數範圍,索引直接對應 RankType 數值,兩份表大小固定要跟著 RankType 一起維護。之後
## 想改難度曲線只改這兩個常數,不用動下面 get_random_party() 本體邏輯。上限對齊
## LevelSystem.level_required_exp 的滿級 20 級。
## Vector2i(下限, 上限),兩者相等代表固定值不隨機。
const RANK_LEVEL_RANGE: Array[Vector2i] = [
	Vector2i(1, 1),    # F
	Vector2i(2, 5),    # E
	Vector2i(4, 9),    # D
	Vector2i(9, 14),   # C
	Vector2i(14, 20),  # B
	Vector2i(20, 20),  # A
	Vector2i(20, 20),  # S
	Vector2i(20, 20),  # SS
	Vector2i(20, 20),  # SSS
]
const RANK_PARTY_SIZE_RANGE: Array[Vector2i] = [
	Vector2i(1, 2),  # F
	Vector2i(2, 3),  # E
	Vector2i(3, 4),  # D
	Vector2i(4, 5),  # C
	Vector2i(5, 6),  # B
	Vector2i(6, 6),  # A
	Vector2i(6, 6),  # S
	Vector2i(6, 6),  # SS
	Vector2i(6, 6),  # SSS
]

## rank_type/nation/level 皆為 -1 = 不指定,三者互相獨立、任意組合:
## - rank_type 沒指定時,先骰一個隨機 RankType 當這個 Party 的評級(party.rank_type),
##   整隊角色統一套用該評級——不再是每個角色各自獨立隨機 Bloodline Rank,才能讓
##   RANK_LEVEL_RANGE/RANK_PARTY_SIZE_RANGE 對得上「這隊多強」。nation 仍然獨立,不受
##   rank_type 是否指定影響。
## - 人數不再固定 6 人,改成依最終 rank_type 從 RANK_PARTY_SIZE_RANGE 骰。
## - level 是 Party 層級的生成條件,沒指定就依最終 rank_type 從 RANK_LEVEL_RANGE 骰;
##   指定時整隊角色統一換上同一顆 LevelSystem.new(level),不吃曲線表。
static func get_random_party(rank_type: int = -1, nation: int = -1, level: int = -1) -> Party:
	var resolved_rank: int = rank_type if rank_type != -1 else Util.get_random_enum_value(GameEnums.RankType)
	var size_range := RANK_PARTY_SIZE_RANGE[resolved_rank]
	var party_size := Util.get_random_int(size_range.x, size_range.y + 1)
	var level_range := RANK_LEVEL_RANGE[resolved_rank]
	var resolved_level := level if level != -1 else Util.get_random_int(level_range.x, level_range.y + 1)

	var characteres: Array[Character] = []
	for i in range(party_size):
		var character := CharacterController.get_random_character(resolved_rank, nation)
		character.level_system = LevelSystem.new(resolved_level)
		# character.weapon = GameEnums.WeaponType.SHIELD
		# character.skill_list = SkillController.get_skill_list_by_weapon(character.weapon)
		characteres.append(character)
	var leader: Character = Util.get_random_from_array(characteres)
	var party := Party.new("隨機小隊", characteres, leader)
	party.ultimates = UltimateLibrary.default_ultimates()
	party.rank_type = resolved_rank
	return party
