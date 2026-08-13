class_name SkillEffectLibrary
extends RefCounted

## 技能「效果」庫:專門存放技能的數值計算與戰鬥表現(log_event/造成傷害等),
## SkillLibrary 只負責組裝技能資料(名稱/rank/範圍/綁定武器…),實際效果一律
## 透過 Callable(SkillEffectLibrary, "xxx") 帶入 Skill.action。
##
## 新增效果時優先重用 _attack_value()/_defense_value()/_cast_attack_skill() 這幾個
## 共用計算(基本攻擊 BattleHero.attack() 也共用同一份武器素質配對),保持每個效果
## function 只需描述「綁定哪個武器」。

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
## 盾=力量*0.4+體質*0.6、匕首=力量*0.4+敏捷*0.6、權杖=智慧*0.4+信仰*0.6,
## 其餘(劍、徒手 EMPTY)一律用力量。
static func _attack_value(self_hero: BattleHero, weapon: int) -> float:
	match weapon:
		GameEnums.WeaponType.STAFF:
			return self_hero.intelligence
		GameEnums.WeaponType.BOW:
			return self_hero.dexterity
		GameEnums.WeaponType.SHIELD:
			return self_hero.strength * 0.4 + self_hero.vitality * 0.6
		GameEnums.WeaponType.DAGGER:
			return self_hero.strength * 0.4 + self_hero.agility * 0.6
		GameEnums.WeaponType.SCEPTER:
			return self_hero.intelligence * 0.4 + self_hero.mentality * 0.6
		_: # SWORD、EMPTY(徒手比照劍)
			return self_hero.strength

## 依武器決定防禦方要用哪個素質:法杖/權杖打的是信仰,其餘一律是體質。
static func _defense_value(enemy_hero: BattleHero, weapon: int) -> float:
	match weapon:
		GameEnums.WeaponType.STAFF, GameEnums.WeaponType.SCEPTER:
			return enemy_hero.mentality
		_:
			return enemy_hero.vitality

## 基本攻擊(BattleHero.attack() 專用):套用跟技能一樣的武器素質配對,倍率固定 1。
static func basic_attack_damage(self_hero: BattleHero, enemy_hero: BattleHero, weapon: int) -> float:
	return _skill_damage(_attack_value(self_hero, weapon), _defense_value(enemy_hero, weapon), 1.0)

## 攻擊類技能共用的表現:記一筆 skill 事件(以 primary_target 決定動畫朝向與戰報文字,
## detail 帶施法前的選技能/選目標判定明細),再對 skill.resolve_targets() 算出的每個
## 目標各自判定閃避、各自判定暴擊、各自造成傷害——範圍內每個目標都是獨立個體,誰命中
## 誰沒命中、有沒有暴擊、扣多少血一律照自己的敏捷/防禦/DEX/VIT(MEN)素質分開算,
## 不會因為波及多人而共用同一次判定結果,也不因人數膨脹或衰減。
static func _cast_attack_skill(self_hero: BattleHero, primary_target: BattleHero, skill: Skill, weapon: int, cast_detail: String = "") -> void:
	self_hero.battle.log_event({
		"type": "skill", "actor": self_hero, "actor_name": self_hero.name,
		"target": primary_target, "target_name": primary_target.name, "skill_name": skill.name,
		"detail": cast_detail,
	})

	var attack_value := _attack_value(self_hero, weapon)
	for enemy_hero in skill.resolve_targets(self_hero, primary_target):
		var dodge_check := self_hero.judge_dodge(self_hero, enemy_hero)
		if dodge_check.dodged:
			continue
		var damage := _skill_damage(attack_value, _defense_value(enemy_hero, weapon), skill.skill_ratio)
		var crit_check := self_hero.judge_crit(self_hero, enemy_hero)
		if crit_check.critical:
			damage *= BattleHero.CRIT_DAMAGE_MULTIPLIER
		enemy_hero.be_attacked(damage, crit_check.critical, "%s\n\n%s" % [dodge_check.detail, crit_check.detail])


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

## 權杖:智慧*0.4 + 信仰*0.6 vs 信仰
static func scepter_attack(self_hero: BattleHero, enemy_hero: BattleHero, skill: Skill, cast_detail: String = "") -> void:
	_cast_attack_skill(self_hero, enemy_hero, skill, GameEnums.WeaponType.SCEPTER, cast_detail)
