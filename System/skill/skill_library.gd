class_name SkillLibrary
extends RefCounted

## 技能總表。依「主動/被動/LEADER」分三個區塊維護,新增技能請加進對應的 function:
## - _active_skills():消耗本回合行動骰選(SKILL 類型)才會施放的技能,任何角色只要
##   武器相符就能用,包含傷害/治療/增益/減益,不限攻擊
## - _passive_skills():不吃行動骰選——開戰時直接套用一次(Skill.is_passive=true,
##   見 BattleHero._apply_passive_skills()),或是像「守護」這種效果完全交給
##   BattleHero.resolve_guard() 反應式判定的技能
## - _leader_skills():只有隊長(BattleHero.is_leader)能用(Skill.is_leader_skill=true),
##   其餘規則跟主動技能一樣要消耗行動骰選
## 技能的數值計算/戰鬥表現一律寫在 SkillEffectLibrary,這裡只組裝資料
## (名稱/rank/範圍/綁定武器…),action 一律用 Callable(SkillEffectLibrary, "xxx") 帶入。

static func build() -> Array[Skill]:
	var library: Array[Skill] = []
	library.append_array(_active_skills())
	library.append_array(_passive_skills())
	library.append_array(_leader_skills())
	return library

static func _active_skills() -> Array[Skill]:
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
		false, #	是否為被動技能
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
		false,
		30.0,
		3.0,
		Callable(SkillEffectLibrary, "dagger_attack")
	))

	skills.append(Skill.new(
		"聖光審判",
		"高舉捕夢網召喚聖光,攻擊敵方",
		GameEnums.RankType.E,
		2,
		GameEnums.AreaShape.SINGLE,
		1,
		GameEnums.PotentialType.MENTALITY,
		GameEnums.SkillType.ATTACK,
		GameEnums.WeaponType.DREAMCATCHER,
		false,
		false,
		30.0,
		3.0,
		Callable(SkillEffectLibrary, "dreamcatcher_attack")
	))

	skills.append(Skill.new(
		"治癒", #	C. 以自身為中心,兩格內的隊友都恢復 HP,治療量 = MEN×2
		"捕夢網低語安撫的夢境,身旁的隊友隨之恢復傷勢",
		GameEnums.RankType.E,
		0, #	距離:自我中心施放,不需要鎖定/移動
		GameEnums.AreaShape.RADIUS,
		3, #	範圍大小:曼哈頓距離 ≤2(3-1)
		GameEnums.PotentialType.MENTALITY,
		GameEnums.SkillType.HEAL,
		GameEnums.WeaponType.DREAMCATCHER,
		false,
		false,
		25.0,
		2.0, #	治療量 = 施法者 MEN × 2.0
		Callable(SkillEffectLibrary, "dreamcatcher_heal")
	))

	skills.append(Skill.new(
		"降咒", #	E. 目標周圍 2 格內的敵人 AGI/STR 各下降 20%,持續 3 回合
		"以捕夢網編織夢魘,詛咒目標與周遭的敵人手腳遲鈍",
		GameEnums.RankType.E,
		2, #	距離:鎖定目標需在 2 格內
		GameEnums.AreaShape.RADIUS,
		3, #	範圍大小:延伸 2 格(3-1)
		GameEnums.PotentialType.MENTALITY,
		GameEnums.SkillType.DEBUFF,
		GameEnums.WeaponType.DREAMCATCHER,
		false,
		false,
		25.0,
		-0.2, #	每項素質 -20%(負值代表減益)
		Callable(SkillEffectLibrary, "curse_debuff")
	))

	return skills


static func _passive_skills() -> Array[Skill]:
	var skills: Array[Skill] = []

	skills.append(Skill.new(
		"智勇兼備", #	A. 被動永久提升力量與智慧各 30%
		"與生俱來的堅毅與才智,永久提升力量與智慧",
		GameEnums.RankType.E,
		0,
		GameEnums.AreaShape.SINGLE,
		1,
		GameEnums.PotentialType.STRENGTH,
		GameEnums.SkillType.BUFF,
		GameEnums.WeaponType.EMPTY, #	無綁定,任何角色都能有這個被動
		false,
		true, #	被動技能
		0.0, #	被動不吃行動骰選,權重無意義
		0.3, #	力量/智慧各 +30%
		Callable(SkillEffectLibrary, "wisdom_and_valor_passive")
	))

	skills.append(Skill.new(
		"守護", #	B. 盾系角色機率頂替附近友軍承受單體物理攻擊,傷害再減 30%
		"盾系角色的本能反應:友軍受到單體物理攻擊時,自己可能飛身頂替承受",
		GameEnums.RankType.E,
		0,
		GameEnums.AreaShape.SINGLE,
		1,
		GameEnums.PotentialType.VITALITY,
		GameEnums.SkillType.DEFEND,
		GameEnums.WeaponType.SHIELD,
		false,
		true, #	被動技能(反應式,實際判定在 BattleHero.resolve_guard())
		0.0,
		0.0,
		Callable(SkillEffectLibrary, "guard_passive_noop")
	))

	return skills


static func _leader_skills() -> Array[Skill]:
	var skills: Array[Skill] = []

	skills.append(Skill.new(
		"大將之風", #	D. 隊長專屬,全隊(含自己)力量/敏捷/靈巧各 +20%,持續 3 回合
		"隊長振奮全軍士氣,全隊力量、敏捷、靈巧一齊提升",
		GameEnums.RankType.E,
		0,
		GameEnums.AreaShape.ALL_ALLIES, #	無視距離,命中施法者本人+全隊存活隊友
		1,
		GameEnums.PotentialType.STRENGTH,
		GameEnums.SkillType.BUFF,
		GameEnums.WeaponType.EMPTY, #	無綁定,任何武器的隊長都能用
		true, #	LEADER 技能,只有隊長能用
		false,
		25.0,
		0.2, #	每項素質 +20%
		Callable(SkillEffectLibrary, "commander_bearing_buff")
	))

	return skills
