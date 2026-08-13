class_name SkillEffectLibrary
extends RefCounted

## 技能「效果」庫:專門存放技能的數值計算與戰鬥表現(log_event/造成傷害等),
## SkillLibrary 只負責組裝技能資料(名稱/rank/範圍/綁定武器…),實際效果一律
## 透過 Callable(SkillEffectLibrary, "xxx") 帶入 Skill.action。
##
## 新增效果時優先重用 _potential_damage()/_log_and_attack() 這兩個共用計算,
## 保持每個效果 function 只需描述「用哪個素質打、打誰的哪個素質」。

## 素質對素質的傷害公式:base = 攻擊素質 * multiplier,
## 依防禦素質(0~200 範圍)按比例減傷,概念與 BattleHero.attack() 的普攻公式一致。
static func _skill_damage(attack_value: float, defense_value: float, multiplier: float) -> float:
	var damage_ratio: float = min(attack_value * multiplier / defense_value, 1.0)
	var damage: float = attack_value * multiplier * damage_ratio 
	return damage

## 攻擊類技能共用的表現:記一筆 skill 事件、對目標造成傷害
static func _log_and_attack(self_hero: BattleHero, enemy_hero: BattleHero, skill: Skill, damage: float) -> void:
	self_hero.battle.log_event({
		"type": "skill", "actor": self_hero, "actor_name": self_hero.name,
		"target": enemy_hero, "target_name": enemy_hero.name, "skill_name": skill.name,
	})
	enemy_hero.be_attacked(damage)


# =========================================================
# 通用技能(不綁武器,徒手也能放)
# =========================================================

# =========================================================
# 六種武器專屬技能 E
# =========================================================

## 法杖:智慧 vs 信仰
static func staff_attack(self_hero: BattleHero, enemy_hero: BattleHero, skill: Skill) -> void:
	var damage := _skill_damage(self_hero.intelligence, enemy_hero.mentality, skill.skill_ratio)
	_log_and_attack(self_hero, enemy_hero, skill, damage)

## 劍:力量 vs 體質
static func sword_attack(self_hero: BattleHero, enemy_hero: BattleHero, skill: Skill) -> void:
	var damage := _skill_damage(self_hero.strength, enemy_hero.vitality, skill.skill_ratio)
	_log_and_attack(self_hero, enemy_hero, skill, damage)

## 弓:靈巧 vs 體質
static func bow_attack(self_hero: BattleHero, enemy_hero: BattleHero, skill: Skill) -> void:
	var damage := _skill_damage(self_hero.perception, enemy_hero.vitality, skill.skill_ratio)
	_log_and_attack(self_hero, enemy_hero, skill, damage)

## 盾:力量 + 體質 vs 體質
static func shield_attack(self_hero: BattleHero, enemy_hero: BattleHero, skill: Skill) -> void:
	var damage := _skill_damage(self_hero.strength * 0.4 + self_hero.vitality * 0.6, enemy_hero.vitality, skill.skill_ratio)
	_log_and_attack(self_hero, enemy_hero, skill, damage)

## 匕首:力量 + 敏捷 vs 體質
static func dagger_attack(self_hero: BattleHero, enemy_hero: BattleHero, skill: Skill) -> void:
	var damage := _skill_damage(self_hero.strength * 0.4 + self_hero.agility * 0.6  , enemy_hero.vitality, skill.skill_ratio)
	_log_and_attack(self_hero, enemy_hero, skill, damage)

## 權杖:智慧 + 信仰 vs 信仰
static func scepter_attack(self_hero: BattleHero, enemy_hero: BattleHero, skill: Skill) -> void:
	var damage := _skill_damage(self_hero.intelligence * 0.4 + self_hero.mentality * 0.6, enemy_hero.mentality, skill.skill_ratio)
	_log_and_attack(self_hero, enemy_hero, skill, damage)
