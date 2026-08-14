class_name SkillEffectLibrary
extends RefCounted

## 技能「效果」庫:專門存放技能的數值計算與戰鬥表現(log_event/造成傷害等),
## SkillLibrary 只負責組裝技能資料(名稱/rank/範圍/綁定武器…),實際效果一律
## 透過 Callable(SkillEffectLibrary, "xxx") 帶入 Skill.action。
##
## 傷害/閃避/暴擊/守護判定一律呼叫 CombatResolver,不直接呼叫 BattleHero 的實例方法——
## BattleHero 的一般攻擊(attack())也是呼叫同一份 CombatResolver,兩邊共用同一套底層,
## 不再互相呼叫對方。新增效果時優先重用 _attack_value()/_defense_value()/
## _cast_attack_skill() 這幾個共用計算,保持每個效果 function 只需描述「綁定哪個武器」。

## 素質對素質的傷害公式:先用「攻擊素質 vs 防禦素質(皆 0~200 範圍)」本身的比例
## 算出封頂上限(damage_ratio,基本攻擊 multiplier=1 時等同這條比例本身),
## 技能倍率(multiplier)只放大最終傷害輸出,不參與「防禦擋不擋得住」的判定——
## 否則像火球術 multiplier=2 這種技能,會變成要防禦贏過「攻擊*2」才不封頂,
## 使封頂(每個目標傷害都一樣)的情況異常頻繁,失去範圍技能命中多人時
## 應該因為各自防禦不同而分出高低傷害的意義。
static func _skill_damage(attack_value: float, defense_value: float, multiplier: float) -> float:
	var damage_ratio: float = min(attack_value / defense_value, 1.0)
	var damage: float = attack_value * multiplier * damage_ratio
	return damage

## 依武器決定攻擊方要用哪個(或哪幾個)素質當輸出:法杖=智慧、弓=靈巧、
## 盾=力量*0.4+體質*0.6、匕首=力量*0.4+敏捷*0.6、捕夢網=智慧*0.4+信仰*0.6,
## 其餘(劍、徒手 EMPTY)一律用力量。
static func _attack_value(self_hero: BattleHero, weapon: GameEnums.WeaponType) -> float:
	match weapon:
		GameEnums.WeaponType.STAFF:
			return self_hero.intelligence
		GameEnums.WeaponType.BOW:
			return self_hero.dexterity
		GameEnums.WeaponType.SHIELD:
			return self_hero.strength * 0.4 + self_hero.vitality * 0.6
		GameEnums.WeaponType.DAGGER:
			return self_hero.strength * 0.4 + self_hero.agility * 0.6
		GameEnums.WeaponType.DREAMCATCHER:
			return self_hero.intelligence * 0.4 + self_hero.mentality * 0.6
		_: # SWORD、EMPTY(徒手比照劍)
			return self_hero.strength

## 依武器決定防禦方要用哪個素質:法杖/捕夢網打的是信仰,其餘一律是體質。
static func _defense_value(enemy_hero: BattleHero, weapon: GameEnums.WeaponType) -> float:
	match weapon:
		GameEnums.WeaponType.STAFF, GameEnums.WeaponType.DREAMCATCHER:
			return enemy_hero.mentality
		_:
			return enemy_hero.vitality

## 基本攻擊(BattleHero.attack() 專用):套用跟技能一樣的武器素質配對,倍率固定 1。
static func basic_attack_damage(self_hero: BattleHero, enemy_hero: BattleHero, weapon: GameEnums.WeaponType) -> float:
	return _skill_damage(_attack_value(self_hero, weapon), _defense_value(enemy_hero, weapon), 1.0)

## 攻擊類技能共用的表現:記一筆 skill 事件(以 primary_target 決定動畫朝向與戰報文字,
## detail 帶施法前的選技能/選目標判定明細),再對 skill.resolve_targets() 算出的每個
## 目標各自判定閃避、各自判定暴擊、各自造成傷害——範圍內每個目標都是獨立個體,誰命中
## 誰沒命中、有沒有暴擊、扣多少血一律照自己的敏捷/防禦/DEX/VIT(MEN)素質分開算,
## 不會因為波及多人而共用同一次判定結果,也不因人數膨脹或衰減。
##
## 單體技能(resolve_targets() 只算出 1 個目標)在這裡先過一次 CombatResolver.resolve_guard()
## ——如果附近有守護技能的友軍頂替,實際受擊的目標會換成守護者(連 skill 事件顯示的
## target 也一併換掉,動畫才會對準真正挨打的人),範圍技能(命中多人)則不觸發守護,
## 因為守護只擋得住「單體」攻擊(見 B. 守護的設計)。
static func _cast_attack_skill(self_hero: BattleHero, primary_target: BattleHero, skill: Skill, weapon: GameEnums.WeaponType, cast_detail: String = "") -> void:
	var targets := skill.resolve_targets(self_hero, primary_target)
	var display_target := primary_target
	var guarded := false
	var guard_damage_multiplier := 1.0

	if targets.size() == 1:
		var guard_result := CombatResolver.resolve_guard(targets[0], self_hero)
		guarded = guard_result.target != targets[0]
		targets = [guard_result.target]
		display_target = guard_result.target
		guard_damage_multiplier = guard_result.damage_multiplier

	self_hero.battle.log_event(SkillEvent.new(self_hero, display_target, skill.name, cast_detail))

	var attack_value := _attack_value(self_hero, weapon)
	for enemy_hero in targets:
		var dodge_check: DodgeResult
		if guarded:
			# 守護的意義就是「用身體擋下來」,擋都擋了就不會再靈巧閃開,直接視為命中。
			dodge_check = DodgeResult.new(false, "%s 挺身守護,直接承受這次攻擊,不判定閃避" % enemy_hero.name)
		else:
			dodge_check = CombatResolver.judge_dodge(self_hero, enemy_hero)
		if dodge_check.dodged:
			continue
		var damage := _skill_damage(attack_value, _defense_value(enemy_hero, weapon), skill.skill_ratio)
		var crit_check := CombatResolver.judge_crit(self_hero, enemy_hero)
		if crit_check.critical:
			damage *= CombatResolver.CRIT_DAMAGE_MULTIPLIER
		var damage_detail := "%s\n\n%s" % [dodge_check.detail, crit_check.detail]
		if guarded:
			damage *= guard_damage_multiplier
			damage_detail += "\n\n此傷害因守護減少 30%"
		CombatResolver.apply_damage(enemy_hero, damage, crit_check.critical, damage_detail)


# =========================================================
# 六種武器專屬技能 E
# =========================================================

## 法杖:智慧 vs 信仰
static func staff_attack(self_hero: BattleHero, enemy_hero: BattleHero, skill: Skill, cast_detail: String = "") -> void:
	_cast_attack_skill(self_hero, enemy_hero, skill, GameEnums.WeaponType.STAFF, cast_detail)

## 劍:力量 vs 體質
static func sword_attack(self_hero: BattleHero, enemy_hero: BattleHero, skill: Skill, cast_detail: String = "") -> void:
	_cast_attack_skill(self_hero, enemy_hero, skill, GameEnums.WeaponType.SWORD, cast_detail)

## 弓:靈巧 vs 體質
static func bow_attack(self_hero: BattleHero, enemy_hero: BattleHero, skill: Skill, cast_detail: String = "") -> void:
	_cast_attack_skill(self_hero, enemy_hero, skill, GameEnums.WeaponType.BOW, cast_detail)

## 盾:力量*0.4 + 體質*0.6 vs 體質
static func shield_attack(self_hero: BattleHero, enemy_hero: BattleHero, skill: Skill, cast_detail: String = "") -> void:
	_cast_attack_skill(self_hero, enemy_hero, skill, GameEnums.WeaponType.SHIELD, cast_detail)

## 匕首:力量*0.4 + 敏捷*0.6 vs 體質
static func dagger_attack(self_hero: BattleHero, enemy_hero: BattleHero, skill: Skill, cast_detail: String = "") -> void:
	_cast_attack_skill(self_hero, enemy_hero, skill, GameEnums.WeaponType.DAGGER, cast_detail)

## 捕夢網:智慧*0.4 + 信仰*0.6 vs 信仰
static func dreamcatcher_attack(self_hero: BattleHero, enemy_hero: BattleHero, skill: Skill, cast_detail: String = "") -> void:
	_cast_attack_skill(self_hero, enemy_hero, skill, GameEnums.WeaponType.DREAMCATCHER, cast_detail)


# =========================================================
# 支援類技能(BUFF/HEAL/DEBUFF)
# =========================================================

## D/E 這類「素質加成/減益」技能共用的時效長度(回合數),不放進 Skill 資料欄位——
## 目前只有這兩個技能用得到,先當常數集中管理,之後若技能一多、時限開始需要各自不同,
## 再考慮改成 Skill 自己的欄位。
const STAT_EFFECT_ROUNDS := 3

## A. 智勇兼備:被動技能,開戰時由 BattleHero._apply_passive_skills() 呼叫一次
## (透過 Skill.apply_passive()),永久(rounds=-1)提升力量與智慧,幅度吃
## skill.skill_ratio(目前 0.3 = 30%)。
static func wisdom_and_valor_passive(self_hero: BattleHero, skill: Skill) -> void:
	self_hero.add_stat_modifier(GameEnums.PotentialType.STRENGTH, skill.skill_ratio, -1)
	self_hero.add_stat_modifier(GameEnums.PotentialType.INTELLIGENCE, skill.skill_ratio, -1)

## B. 守護:被動技能,但效果完全不在這裡發生——它是「友軍受到單體物理攻擊時」的
## 反應式判定,實際邏輯在 CombatResolver.resolve_guard(),由 _cast_attack_skill()/
## BattleHero.attack() 在命中判定前呼叫。這個函式只是給 Skill 建構子一個合法的
## Callable 佔位,apply_passive() 呼叫到也不做任何事。
static func guard_passive_noop(self_hero: BattleHero, skill: Skill) -> void:
	pass

## C. 治癒:以施法者自身為中心,範圍內(RADIUS)的存活隊友(不含自己)各自恢復 HP,
## 治療量 = 施法者 MEN(信仰) × skill.skill_ratio(目前 2.0 = 2 倍),不吃防禦、
## 不會被閃避,每個目標各自記一筆 heal 事件。
static func dreamcatcher_heal(self_hero: BattleHero, primary_target: BattleHero, skill: Skill, cast_detail: String = "") -> void:
	self_hero.battle.log_event(SkillEvent.new(self_hero, self_hero, skill.name, cast_detail))

	var heal_value: float = self_hero.mentality * skill.skill_ratio
	var heal_detail := "%s 治療量 = MEN(%.1f)×%.1f = %.1f" % [
		self_hero.name, self_hero.mentality, skill.skill_ratio, heal_value,
	]
	for ally in skill.resolve_targets(self_hero, self_hero):
		CombatResolver.apply_heal(ally, heal_value, heal_detail)

## D. 大將之風:LEADER 技能,area_shape=ALL_ALLIES(見 Skill.resolve_targets()),
## 對施法者本人+全隊存活隊友一次套用力量/敏捷/靈巧 +skill.skill_ratio(目前 0.2 =
## 20%),持續 STAT_EFFECT_ROUNDS 回合。
static func commander_bearing_buff(self_hero: BattleHero, primary_target: BattleHero, skill: Skill, cast_detail: String = "") -> void:
	self_hero.battle.log_event(SkillEvent.new(self_hero, self_hero, skill.name, cast_detail))

	var targets := skill.resolve_targets(self_hero, self_hero)
	_apply_stat_effect(targets, [
		GameEnums.PotentialType.STRENGTH, GameEnums.PotentialType.AGILITY, GameEnums.PotentialType.DEXTERITY,
	], skill.skill_ratio, STAT_EFFECT_ROUNDS)

## E. 降咒:以鎖定的敵方目標為中心,RADIUS 範圍內的敵人各自被降低敏捷/力量
## skill.skill_ratio(目前 -0.2 = -20%),持續 STAT_EFFECT_ROUNDS 回合;不判定閃避/
## 暴擊(這是詛咒不是傷害,跟魔法攻擊一樣視為無視物理閃躲)。
static func curse_debuff(self_hero: BattleHero, primary_target: BattleHero, skill: Skill, cast_detail: String = "") -> void:
	self_hero.battle.log_event(SkillEvent.new(self_hero, primary_target, skill.name, cast_detail))

	var targets := skill.resolve_targets(self_hero, primary_target)
	_apply_stat_effect(targets, [
		GameEnums.PotentialType.AGILITY, GameEnums.PotentialType.STRENGTH,
	], skill.skill_ratio, STAT_EFFECT_ROUNDS)

## D/E 共用:對多個目標套用同一組素質修正,每個目標各自記一筆 stat_effect 事件
## (給戰報 UI/頭像箭頭用),multiplier 正值是增益、負值是減益。
static func _apply_stat_effect(targets: Array[BattleHero], potential_types: Array[int], multiplier: float, rounds: int) -> void:
	for target in targets:
		for potential_type in potential_types:
			target.add_stat_modifier(potential_type, multiplier, rounds)
		target.battle.log_event(StatEffectEvent.new(target, potential_types, multiplier, rounds))
