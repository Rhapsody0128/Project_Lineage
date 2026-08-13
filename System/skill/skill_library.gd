class_name SkillLibrary
extends RefCounted

## 技能總表。依 rank 分區塊維護,新增技能請加進對應 rank 的 function,
## 若新增新 rank 區塊,記得在 build() 裡 append_array 進來。
## 技能的數值計算/戰鬥表現一律寫在 SkillEffectLibrary,這裡只組裝資料
## (名稱/rank/範圍/綁定武器…),action 一律用 Callable(SkillEffectLibrary, "xxx") 帶入。

static func build() -> Array[Skill]:
	var library: Array[Skill] = []
	library.append_array(_weapon_skills())
	library.append_array(_passive_skills())
	return library

static func _weapon_skills() -> Array[Skill]:
	var skills: Array[Skill] = []

	skills.append(Skill.new(
		"火球術", #	名稱
		"對範圍敵人造成遠距離範圍傷害", #	描述
		GameEnums.RankType.E, #	Rank
		3, #	距離
		GameEnums.AreaShape.RADIUS, #	範圍形狀
		2, #	範圍大小
		GameEnums.PotentialType.INTELLIGENCE, #	影響屬性
		GameEnums.SkillType.ATTACK, #	技能類型
		GameEnums.WeaponType.STAFF, #	綁定武器
		false, #	是否為領袖技能
		25.0, #	多技能時施放權重,
		2.0, #	技能倍率,
		Callable(SkillEffectLibrary, "staff_attack") #	技能效果 function
	))

	skills.append(Skill.new(
		"狂擊",
		"手持長劍捲起一陣旋風,連消帶打劈向敵人",
		GameEnums.RankType.E,
		1,
		GameEnums.AreaShape.SINGLE,
		1,
		GameEnums.PotentialType.STRENGTH,
		GameEnums.SkillType.ATTACK,
		GameEnums.WeaponType.SWORD,
		false,
		30.0,
		3.0,
		Callable(SkillEffectLibrary, "sword_attack")
	))

	skills.append(Skill.new(
		"精準射擊",
		"拉滿弓弦射出一箭,能擊中遠距離敵人",
		GameEnums.RankType.E,
		4,
		GameEnums.AreaShape.SINGLE,
		1,
		GameEnums.PotentialType.DEXTERITY,
		GameEnums.SkillType.ATTACK,
		GameEnums.WeaponType.BOW,
		false,
		30.0,
		3.0,
		Callable(SkillEffectLibrary, "bow_attack")
	))

	skills.append(Skill.new(
		"盾牌重擊",
		"以盾牌邊緣狠狠撞擊敵人",
		GameEnums.RankType.E,
		1,
		GameEnums.AreaShape.SINGLE,
		1,
		GameEnums.PotentialType.VITALITY,
		GameEnums.SkillType.ATTACK,
		GameEnums.WeaponType.SHIELD,
		false,
		30.0,
		3.0,
		Callable(SkillEffectLibrary, "shield_attack")
	))

	skills.append(Skill.new(
		"影襲",
		"欺近敵人身側,以匕首找出防禦空隙突刺",
		GameEnums.RankType.E,
		1,
		GameEnums.AreaShape.SINGLE,
		1,
		GameEnums.PotentialType.AGILITY,
		GameEnums.SkillType.ATTACK,
		GameEnums.WeaponType.DAGGER,
		false,
		30.0,
		3.0,
		Callable(SkillEffectLibrary, "dagger_attack")
	))

	skills.append(Skill.new(
		"聖光審判",
		"高舉權杖召喚聖光,攻擊敵方",
		GameEnums.RankType.E,
		2,
		GameEnums.AreaShape.SINGLE,
		1,
		GameEnums.PotentialType.MENTALITY,
		GameEnums.SkillType.ATTACK,
		GameEnums.WeaponType.SCEPTER,
		false,
		30.0,
		3.0,
		Callable(SkillEffectLibrary, "scepter_attack")
	))

	return skills


static func _passive_skills() -> Array[Skill]:
	var skills: Array[Skill] = []

	skills.append(Skill.new(
		"", #	名稱
		"對範圍敵人造成遠距離範圍傷害", #	描述
		GameEnums.RankType.E, #	Rank
		3, #	距離
		GameEnums.AreaShape.RADIUS, #	範圍形狀
		2, #	範圍大小
		GameEnums.PotentialType.INTELLIGENCE, #	影響屬性
		GameEnums.SkillType.ATTACK, #	技能類型
		GameEnums.WeaponType.STAFF, #	綁定武器
		false, #	是否為領袖技能
		25.0, #	多技能時施放權重,
		2.0, #	技能倍率,
		Callable(SkillEffectLibrary, "staff_attack") #	技能效果 function
	))