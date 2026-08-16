class_name PartyController
extends RefCounted

## 小隊編制之後會開放玩家自行配置,目前先寫死隨機 6 名角色
const RANDOM_PARTY_SIZE := 12

## 除錯用:強制全部角色使用同一種武器,方便單獨測試某個武器的技能表現。
## 預設 -1 代表關閉(維持 CharacterController.RANDOM_WEAPON_POOL 的正常隨機),
## 要測試特定武器時把這裡改成想測的 GameEnums.WeaponType 即可,不要動 get_random_party()
## 本體邏輯。
const DEBUG_FORCE_WEAPON: int = -1

static func get_random_party() -> Party:
	var characteres: Array[Character] = []
	for i in range(RANDOM_PARTY_SIZE):
		var character := CharacterController.get_random_character()
		# character.weapon = GameEnums.WeaponType.SHIELD
		# character.skill_list = SkillController.get_skill_list_by_weapon(character.weapon)
		characteres.append(character)
	var leader: Character = Util.get_random_from_array(characteres)
	var party := Party.new("隨機小隊", characteres, leader)
	party.ultimates = UltimateLibrary.default_ultimates()
	return party
