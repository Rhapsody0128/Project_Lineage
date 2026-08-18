class_name PartyController
extends RefCounted

## 小隊編制之後會開放玩家自行配置,目前先寫死隨機 6 名角色
const RANDOM_PARTY_SIZE := 6

## 除錯用:強制全部角色使用同一種武器,方便單獨測試某個武器的技能表現。
## 預設 -1 代表關閉(維持 CharacterController.RANDOM_WEAPON_POOL 的正常隨機),
## 要測試特定武器時把這裡改成想測的 GameEnums.WeaponType 即可,不要動 get_random_party()
## 本體邏輯。
const DEBUG_FORCE_WEAPON: int = -1

## rank_type/nation/level 皆為 -1 = 不指定,三者互相獨立、任意組合:
## - rank_type/nation 直接轉呼叫 CharacterController.get_random_character(),不指定就
##   維持隊內每個角色 Bloodline Rank/Potential Rank/國家各自獨立隨機。
## - level 是 Party 層級的生成條件,不指定就維持角色原本從 Lv1 開始的邏輯;指定時整隊
##   角色統一換上同一顆 LevelSystem.new(level)。
## - party.rank_type:呼叫端有指定 rank_type 就直接記錄,沒指定就額外隨機骰一個存起來
##   當這個 Party 的評級標籤(見 Party.rank_type 欄位註解),供戰鬥勝利 EXP 判定用
##   (System/battle/battle_reward.gd),不影響隊內角色各自的隨機生成結果。
static func get_random_party(rank_type: int = -1, nation: int = -1, level: int = -1) -> Party:
	var characteres: Array[Character] = []
	for i in range(RANDOM_PARTY_SIZE):
		var character := CharacterController.get_random_character(rank_type, nation)
		if level != -1:
			character.level_system = LevelSystem.new(level)
		# character.weapon = GameEnums.WeaponType.SHIELD
		# character.skill_list = SkillController.get_skill_list_by_weapon(character.weapon)
		characteres.append(character)
	var leader: Character = Util.get_random_from_array(characteres)
	var party := Party.new("隨機小隊", characteres, leader)
	party.ultimates = UltimateLibrary.default_ultimates()
	party.rank_type = rank_type if rank_type != -1 else Util.get_random_enum_value(GameEnums.RankType)
	return party
