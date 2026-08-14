class_name SkillLibrary
extends RefCounted

## 技能總表。依「主動/被動/LEADER」分三個區塊維護,新增技能請加進對應的 function:
## - _active_skills():消耗本回合行動骰選(SKILL 類型)才會施放的技能,任何角色只要
##   武器相符就能用,包含傷害/治療/增益/減益,不限攻擊
## - _passive_skills():不吃行動骰選——開戰時直接套用一次(SkillBuilder.passive(),
##   見 BattleHero._apply_passive_skills()),或是像「守護」這種效果完全交給
##   CombatResolver.resolve_guard() 反應式判定的技能(SkillBuilder.guard_skill())
## - _leader_skills():只有隊長(BattleHero.is_leader)能用(SkillBuilder.leader_skill()),
##   其餘規則跟主動技能一樣要消耗行動骰選
## 技能的數值計算/戰鬥表現一律寫在 SkillEffectLibrary,這裡只組裝資料。
## 用 SkillBuilder 鏈式組裝取代舊版 14 個位置參數的建構子——GDScript 沒有具名參數,
## 順序錯了的位置參數會靜默編譯成功、值全部對錯位,鏈式方法呼叫至少方法名拼錯會直接
## 編譯失敗。

static func build() -> Array[Skill]:
	var library: Array[Skill] = []
	library.append_array(_active_skills())
	library.append_array(_passive_skills())
	library.append_array(_leader_skills())
	return library

static func _active_skills() -> Array[Skill]:
	var skills: Array[Skill] = []

	skills.append(SkillBuilder.new()
		.name("火球術")
		.description("對範圍敵人造成遠距離範圍傷害")
		.rank(GameEnums.RankType.E)
		.skill_range(3)
		.area_shape(GameEnums.AreaShape.RADIUS)
		.area_size(2)
		.effect_stat(GameEnums.PotentialType.INTELLIGENCE)
		.skill_type(GameEnums.SkillType.ATTACK)
		.bind_weapon(GameEnums.WeaponType.STAFF)
		.base_chance(25.0)
		.skill_ratio(2.0)
		.action(Callable(SkillEffectLibrary, "staff_attack"))
		.build())

	skills.append(SkillBuilder.new()
		.name("狂擊")
		.description("手持長劍捲起一陣旋風,連消帶打劈向敵人")
		.rank(GameEnums.RankType.E)
		.skill_range(1)
		.area_shape(GameEnums.AreaShape.SINGLE)
		.area_size(1)
		.effect_stat(GameEnums.PotentialType.STRENGTH)
		.skill_type(GameEnums.SkillType.ATTACK)
		.bind_weapon(GameEnums.WeaponType.SWORD)
		.base_chance(30.0)
		.skill_ratio(3.0)
		.action(Callable(SkillEffectLibrary, "sword_attack"))
		.build())

	skills.append(SkillBuilder.new()
		.name("精準射擊")
		.description("拉滿弓弦射出一箭,能擊中遠距離敵人")
		.rank(GameEnums.RankType.E)
		.skill_range(4)
		.area_shape(GameEnums.AreaShape.SINGLE)
		.area_size(1)
		.effect_stat(GameEnums.PotentialType.DEXTERITY)
		.skill_type(GameEnums.SkillType.ATTACK)
		.bind_weapon(GameEnums.WeaponType.BOW)
		.base_chance(30.0)
		.skill_ratio(3.0)
		.action(Callable(SkillEffectLibrary, "bow_attack"))
		.build())

	skills.append(SkillBuilder.new()
		.name("盾牌重擊")
		.description("以盾牌邊緣狠狠撞擊敵人")
		.rank(GameEnums.RankType.E)
		.skill_range(1)
		.area_shape(GameEnums.AreaShape.SINGLE)
		.area_size(1)
		.effect_stat(GameEnums.PotentialType.VITALITY)
		.skill_type(GameEnums.SkillType.ATTACK)
		.bind_weapon(GameEnums.WeaponType.SHIELD)
		.base_chance(30.0)
		.skill_ratio(3.0)
		.action(Callable(SkillEffectLibrary, "shield_attack"))
		.build())

	skills.append(SkillBuilder.new()
		.name("影襲")
		.description("欺近敵人身側,以匕首找出防禦空隙突刺")
		.rank(GameEnums.RankType.E)
		.skill_range(1)
		.area_shape(GameEnums.AreaShape.SINGLE)
		.area_size(1)
		.effect_stat(GameEnums.PotentialType.AGILITY)
		.skill_type(GameEnums.SkillType.ATTACK)
		.bind_weapon(GameEnums.WeaponType.DAGGER)
		.base_chance(30.0)
		.skill_ratio(3.0)
		.action(Callable(SkillEffectLibrary, "dagger_attack"))
		.build())

	skills.append(SkillBuilder.new()
		.name("聖光審判")
		.description("高舉捕夢網召喚聖光,攻擊敵方")
		.rank(GameEnums.RankType.E)
		.skill_range(2)
		.area_shape(GameEnums.AreaShape.SINGLE)
		.area_size(1)
		.effect_stat(GameEnums.PotentialType.MENTALITY)
		.skill_type(GameEnums.SkillType.ATTACK)
		.bind_weapon(GameEnums.WeaponType.DREAMCATCHER)
		.base_chance(30.0)
		.skill_ratio(3.0)
		.action(Callable(SkillEffectLibrary, "dreamcatcher_attack"))
		.build())

	skills.append(SkillBuilder.new()
		.name("治癒") # C. 以自身為中心,兩格內的隊友都恢復 HP,治療量 = MEN×2
		.description("捕夢網低語安撫的夢境,身旁的隊友隨之恢復傷勢")
		.rank(GameEnums.RankType.E)
		.skill_range(0) # 自我中心施放,不需要鎖定/移動
		.area_shape(GameEnums.AreaShape.RADIUS)
		.area_size(3) # 曼哈頓距離 ≤2(3-1)
		.effect_stat(GameEnums.PotentialType.MENTALITY)
		.skill_type(GameEnums.SkillType.HEAL)
		.bind_weapon(GameEnums.WeaponType.DREAMCATCHER)
		.base_chance(25.0)
		.skill_ratio(2.0) # 治療量 = 施法者 MEN × 2.0
		.action(Callable(SkillEffectLibrary, "dreamcatcher_heal"))
		.build())

	skills.append(SkillBuilder.new()
		.name("降咒") # E. 目標周圍 2 格內的敵人 AGI/STR 各下降 20%,持續 3 回合
		.description("以捕夢網編織夢魘,詛咒目標與周遭的敵人手腳遲鈍")
		.rank(GameEnums.RankType.E)
		.skill_range(2) # 鎖定目標需在 2 格內
		.area_shape(GameEnums.AreaShape.RADIUS)
		.area_size(3) # 延伸 2 格(3-1)
		.effect_stat(GameEnums.PotentialType.MENTALITY)
		.skill_type(GameEnums.SkillType.DEBUFF)
		.bind_weapon(GameEnums.WeaponType.DREAMCATCHER)
		.base_chance(25.0)
		.skill_ratio(-0.2) # 每項素質 -20%(負值代表減益)
		.buffed_stats([GameEnums.PotentialType.AGILITY, GameEnums.PotentialType.STRENGTH])
		.action(Callable(SkillEffectLibrary, "curse_debuff"))
		.build())

	return skills


static func _passive_skills() -> Array[Skill]:
	var skills: Array[Skill] = []

	skills.append(SkillBuilder.new()
		.name("智勇兼備") # A. 被動永久提升力量與智慧各 30%
		.description("與生俱來的堅毅與才智,永久提升力量與智慧")
		.rank(GameEnums.RankType.E)
		.skill_range(0)
		.area_shape(GameEnums.AreaShape.SINGLE)
		.area_size(1)
		.effect_stat(GameEnums.PotentialType.STRENGTH)
		.skill_type(GameEnums.SkillType.BUFF)
		.bind_weapon(GameEnums.WeaponType.EMPTY) # 無綁定,任何角色都能有這個被動
		.passive()
		.base_chance(0.0) # 被動不吃行動骰選,權重無意義
		.skill_ratio(0.3) # 力量/智慧各 +30%
		.action(Callable(SkillEffectLibrary, "wisdom_and_valor_passive"))
		.build())

	skills.append(SkillBuilder.new()
		.name("守護") # B. 盾系角色機率頂替附近友軍承受單體物理攻擊,傷害再減 30%
		.description("盾系角色的本能反應:友軍受到單體物理攻擊時,自己可能飛身頂替承受")
		.rank(GameEnums.RankType.E)
		.skill_range(0)
		.area_shape(GameEnums.AreaShape.SINGLE)
		.area_size(1)
		.effect_stat(GameEnums.PotentialType.VITALITY)
		.skill_type(GameEnums.SkillType.DEFEND)
		.bind_weapon(GameEnums.WeaponType.SHIELD)
		.guard_skill() # 被動 + 反應式判定,實際邏輯在 CombatResolver.resolve_guard()
		.base_chance(0.0)
		.skill_ratio(0.0)
		.action(Callable(SkillEffectLibrary, "guard_passive_noop"))
		.build())

	return skills


static func _leader_skills() -> Array[Skill]:
	var skills: Array[Skill] = []

	skills.append(SkillBuilder.new()
		.name("大將之風") # D. 隊長專屬,全隊(含自己)力量/敏捷/靈巧各 +20%,持續 3 回合
		.description("隊長振奮全軍士氣,全隊力量、敏捷、靈巧一齊提升")
		.rank(GameEnums.RankType.E)
		.skill_range(0)
		.area_shape(GameEnums.AreaShape.ALL_ALLIES) # 無視距離,命中施法者本人+全隊存活隊友
		.area_size(1)
		.effect_stat(GameEnums.PotentialType.STRENGTH)
		.skill_type(GameEnums.SkillType.BUFF)
		.bind_weapon(GameEnums.WeaponType.EMPTY) # 無綁定,任何武器的隊長都能用
		.leader_skill()
		.base_chance(25.0)
		.skill_ratio(0.2) # 每項素質 +20%
		.buffed_stats([GameEnums.PotentialType.STRENGTH, GameEnums.PotentialType.AGILITY, GameEnums.PotentialType.DEXTERITY])
		.action(Callable(SkillEffectLibrary, "commander_bearing_buff"))
		.build())

	return skills
