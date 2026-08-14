class_name PartyController
extends RefCounted

## 小隊編制之後會開放玩家自行配置,目前先寫死隨機 6 名角色
const RANDOM_PARTY_SIZE := 6

static func get_random_party() -> Party:
	var heroes: Array[Hero] = []
	for i in range(RANDOM_PARTY_SIZE):
		var hero := HeroController.get_random_hero()
		# hero.level_system.gain_exp(999999)
		hero.weapon = GameEnums.WeaponType.DREAMCATCHER # 先固定給夢境捕手,方便測試技能
		hero.skill_list = SkillController.get_skill_list_by_weapon(hero.weapon)
		heroes.append(hero)
	var leader: Hero = Util.get_random_from_array(heroes)
	return Party.new("隨機小隊", heroes, leader)
