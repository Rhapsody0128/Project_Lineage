class_name UltimateEffectLibrary
extends RefCounted

## 奧義「效果」庫:UltimateLibrary 只負責組裝奧義資料(名稱/台詞/延遲回合/次數限制…),
## 這裡只放「生效當下」的數值效果(治療/傷害等),透過 Callable(UltimateEffectLibrary,
## "xxx") 帶入 Ultimate.resolve_action,寫法比照 SkillEffectLibrary。施放/生效的戰報
## 事件(台詞)由 Ultimate.cast()/resolve() 自己記錄,這裡不用重複處理。治療/傷害一律
## 呼叫 CombatResolver,不自己動手改 HP。

## 天降甘霖:生效當下,全體友軍(含施法者本人)恢復生命上限的 Ultimate.effect_ratio
## (目前 0.4 = 40%)。
static func rain_of_blessing_resolve(caster: BattleCharacter, ultimate: Ultimate) -> void:
	var targets: Array[BattleCharacter] = caster.allies.duplicate()
	if not caster.is_disabled:
		targets.append(caster)

	for target in targets:
		var heal_value: float = target.hp_max * ultimate.effect_ratio
		var detail := "奧義「%s」生效:%s 恢復生命上限(%d)的 %.0f%% = %.1f" % [
			ultimate.name, target.name, target.hp_max, ultimate.effect_ratio * 100.0, heal_value,
		]
		CombatResolver.apply_heal(target, heal_value, detail)

## 龍捲風:生效當下,敵方全體(存活中)各自受到「自己」生命上限的 Ultimate.effect_ratio
## (目前 0.2 = 20%)傷害——不吃防禦、不判定閃避/暴擊,單純是天災。
static func tornado_resolve(caster: BattleCharacter, ultimate: Ultimate) -> void:
	for target in caster.enemies:
		var damage_value: float = target.hp_max * ultimate.effect_ratio
		var detail := "奧義「%s」生效:%s 受到生命上限(%d)的 %.0f%% = %.1f 傷害" % [
			ultimate.name, target.name, target.hp_max, ultimate.effect_ratio * 100.0, damage_value,
		]
		CombatResolver.apply_damage(target, damage_value, false, detail)


# =========================================================
# 共用小工具:F 級以上 16 個奧義共用的目標蒐集/套用邏輯,寫法比照
# SkillEffectLibrary 的 _apply_stat_effect()/_apply_status_mechanics()。
# =========================================================

## 自身向奧義的目標:全體存活友軍 + 施法者本人(施法者未陣亡才算入,比照天降甘霖既有寫法)。
static func _ally_targets(caster: BattleCharacter) -> Array[BattleCharacter]:
	var targets: Array[BattleCharacter] = caster.allies.duplicate()
	if not caster.is_disabled:
		targets.append(caster)
	return targets

## 護盾套用,自帶 ShieldEvent 記錄(比照 SkillEffectLibrary.shield())。護盾量吃各目標
## 自己的 hp_max 算,所以逐一目標各自呼叫,不是一次餵一批目標共用同一個數值。
static func _apply_shield_to_target(target: BattleCharacter, shield_value: float, ultimate_name: String) -> void:
	target.add_shield(shield_value)
	var detail := "奧義「%s」生效:%s 獲得 %.1f 點護盾" % [ultimate_name, target.name, shield_value]
	target.battle.log_event(ShieldEvent.new(target, roundi(shield_value), roundi(target.shield_points), detail))

## 素質增益/減益套用,自帶 StatEffectEvent 記錄(比照 SkillEffectLibrary._apply_stat_effect())。
static func _apply_stat_effect_to(targets: Array[BattleCharacter], potential_types: Array[int], multiplier: float, rounds: int) -> void:
	for target in targets:
		for potential_type in potential_types:
			target.add_stat_modifier(potential_type, multiplier, rounds)
		target.battle.log_event(StatEffectEvent.new(target, potential_types, multiplier, rounds))

## 全隊限時破防/必定暴擊(正面機制,不判定抵抗,比照 SkillMechanic.GRANT_ARMOR_PIERCE/
## GRANT_GUARANTEED_CRIT 既有規則)。
static func _apply_grant_mechanic_to(targets: Array[BattleCharacter], mechanic: GameEnums.SkillMechanic, rounds: int) -> void:
	for target in targets:
		match mechanic:
			GameEnums.SkillMechanic.GRANT_ARMOR_PIERCE:
				target.apply_armor_pierce_buff(rounds)
			GameEnums.SkillMechanic.GRANT_GUARANTEED_CRIT:
				target.apply_guaranteed_crit_buff(rounds)
		target.battle.log_event(StatusMechanicEvent.new(target, mechanic, true))

## 恐懼/封印/降治療(負面機制,施加前逐一過 CombatResolver.judge_status_resist() 抵抗
## 判定,意志/精神越高越容易抵抗——抵抗成功的目標直接跳過,不記錄事件,比照
## SkillEffectLibrary._apply_status_mechanics() 既有規則)。
static func _apply_resistible_mechanic_to_enemies(caster: BattleCharacter, mechanic: GameEnums.SkillMechanic, rounds: int) -> void:
	for target in caster.enemies:
		var resist := CombatResolver.judge_status_resist(target)
		if resist.resisted:
			continue
		match mechanic:
			GameEnums.SkillMechanic.FEAR:
				target.apply_fear(rounds)
			GameEnums.SkillMechanic.SEAL:
				target.apply_seal(rounds)
			GameEnums.SkillMechanic.HEAL_DOWN:
				target.apply_heal_down(rounds)
		target.battle.log_event(StatusMechanicEvent.new(target, mechanic, true, resist.detail))


# =========================================================
# 自身BUFF奧義(神殿／祭壇,消耗信仰)E~SSS,設計依據見「奧義擴充設計」章節
# =========================================================

## E 聖光壁壘:全體友軍獲得生命上限 effect_ratio(35%)的護盾。
static func light_bastion_resolve(caster: BattleCharacter, ultimate: Ultimate) -> void:
	for target in _ally_targets(caster):
		_apply_shield_to_target(target, target.hp_max * ultimate.effect_ratio, ultimate.name)

## D 戰意昂揚:全體友軍 力量/敏捷 +effect_ratio(20%),持續 duration_rounds 回合。
static func battle_fervor_resolve(caster: BattleCharacter, ultimate: Ultimate) -> void:
	_apply_stat_effect_to(
		_ally_targets(caster),
		[GameEnums.PotentialType.STRENGTH, GameEnums.PotentialType.AGILITY],
		ultimate.effect_ratio, ultimate.duration_rounds
	)

## C 淨罪聖詠:全體友軍回復生命上限 effect_ratio(25%),並各自清除一項異常狀態。
static func purification_hymn_resolve(caster: BattleCharacter, ultimate: Ultimate) -> void:
	for target in _ally_targets(caster):
		var heal_value: float = target.hp_max * ultimate.effect_ratio
		var detail := "奧義「%s」生效:%s 恢復生命上限(%d)的 %.0f%% = %.1f" % [
			ultimate.name, target.name, target.hp_max, ultimate.effect_ratio * 100.0, heal_value,
		]
		CombatResolver.apply_heal(target, heal_value, detail)
		target.cleanse_one_status()

## B 聖劍顯現:全體友軍獲得「破防」,duration_rounds 回合內普攻/技能一律無視防禦。
static func holy_blade_resolve(caster: BattleCharacter, ultimate: Ultimate) -> void:
	_apply_grant_mechanic_to(_ally_targets(caster), GameEnums.SkillMechanic.GRANT_ARMOR_PIERCE, ultimate.duration_rounds)

## A 戰神附體:全體友軍獲得「必定暴擊」,duration_rounds 回合內普攻/技能一律視為暴擊。
static func war_god_possession_resolve(caster: BattleCharacter, ultimate: Ultimate) -> void:
	_apply_grant_mechanic_to(_ally_targets(caster), GameEnums.SkillMechanic.GRANT_GUARANTEED_CRIT, ultimate.duration_rounds)

## S 安寢祝禱:全體友軍回復生命上限 effect_ratio(50%)+ 獲得生命上限 secondary_ratio
## (25%)的護盾。
static func slumber_prayer_resolve(caster: BattleCharacter, ultimate: Ultimate) -> void:
	for target in _ally_targets(caster):
		var heal_value: float = target.hp_max * ultimate.effect_ratio
		var detail := "奧義「%s」生效:%s 恢復生命上限(%d)的 %.0f%% = %.1f" % [
			ultimate.name, target.name, target.hp_max, ultimate.effect_ratio * 100.0, heal_value,
		]
		CombatResolver.apply_heal(target, heal_value, detail)
		_apply_shield_to_target(target, target.hp_max * ultimate.secondary_ratio, ultimate.name)

## SS 神域庇護:全體友軍獲得生命上限 effect_ratio(45%)的護盾 + 「破防」duration_rounds 回合。
static func divine_sanctuary_resolve(caster: BattleCharacter, ultimate: Ultimate) -> void:
	var targets := _ally_targets(caster)
	for target in targets:
		_apply_shield_to_target(target, target.hp_max * ultimate.effect_ratio, ultimate.name)
	_apply_grant_mechanic_to(targets, GameEnums.SkillMechanic.GRANT_ARMOR_PIERCE, ultimate.duration_rounds)

## SSS 創世女神降臨:全體友軍回復 effect_ratio(45%)+ 護盾 secondary_ratio(30%)+ 清除
## 一項異常狀態 + 獲得「必定暴擊」duration_rounds 回合,四個效果一次到位的壓軸奧義。
static func genesis_goddess_resolve(caster: BattleCharacter, ultimate: Ultimate) -> void:
	var targets := _ally_targets(caster)
	for target in targets:
		var heal_value: float = target.hp_max * ultimate.effect_ratio
		var detail := "奧義「%s」生效:%s 恢復生命上限(%d)的 %.0f%% = %.1f" % [
			ultimate.name, target.name, target.hp_max, ultimate.effect_ratio * 100.0, heal_value,
		]
		CombatResolver.apply_heal(target, heal_value, detail)
		_apply_shield_to_target(target, target.hp_max * ultimate.secondary_ratio, ultimate.name)
		target.cleanse_one_status()
	_apply_grant_mechanic_to(targets, GameEnums.SkillMechanic.GRANT_GUARANTEED_CRIT, ultimate.duration_rounds)


# =========================================================
# 傷害敵人奧義(黑暗神殿／禁忌祭壇,消耗詛咒)E~SSS
# =========================================================

## E 凋零詛咒:敵方全體 力量/體質 -effect_ratio(20%),持續 duration_rounds 回合,純減益、
## 不造成傷害。
static func withering_curse_resolve(caster: BattleCharacter, ultimate: Ultimate) -> void:
	_apply_stat_effect_to(
		caster.enemies,
		[GameEnums.PotentialType.STRENGTH, GameEnums.PotentialType.VITALITY],
		-ultimate.effect_ratio, ultimate.duration_rounds
	)

## D 絕望迷霧:敵方全體陷入「降治療」,持續 duration_rounds 回合。
static func despair_mist_resolve(caster: BattleCharacter, ultimate: Ultimate) -> void:
	_apply_resistible_mechanic_to_enemies(caster, GameEnums.SkillMechanic.HEAL_DOWN, ultimate.duration_rounds)

## C 夜嚎凶兆:敵方全體陷入「恐懼」,持續 duration_rounds 回合。
static func night_howl_resolve(caster: BattleCharacter, ultimate: Ultimate) -> void:
	_apply_resistible_mechanic_to_enemies(caster, GameEnums.SkillMechanic.FEAR, ultimate.duration_rounds)

## B 萬鬼緘默:敵方全體陷入「封印」,持續 duration_rounds 回合,無法使用主動技能。
static func silent_ghosts_resolve(caster: BattleCharacter, ultimate: Ultimate) -> void:
	_apply_resistible_mechanic_to_enemies(caster, GameEnums.SkillMechanic.SEAL, ultimate.duration_rounds)

## A 業火焚天:敵方全體受生命上限 effect_ratio(28%)傷害 + 體質 -secondary_ratio(15%),
## 持續 duration_rounds 回合(減益不判定抵抗,比照 SkillEffectLibrary 素質減益慣例)。
static func hellfire_resolve(caster: BattleCharacter, ultimate: Ultimate) -> void:
	for target in caster.enemies:
		var damage_value: float = target.hp_max * ultimate.effect_ratio
		var detail := "奧義「%s」生效:%s 受到生命上限(%d)的 %.0f%% = %.1f 傷害" % [
			ultimate.name, target.name, target.hp_max, ultimate.effect_ratio * 100.0, damage_value,
		]
		CombatResolver.apply_damage(target, damage_value, false, detail)
	_apply_stat_effect_to(caster.enemies, [GameEnums.PotentialType.VITALITY], -ultimate.secondary_ratio, ultimate.duration_rounds)

## S 腐蝕黑潮:敵方全體受生命上限 effect_ratio(25%)傷害 + 陷入「封印」duration_rounds 回合。
static func corrosive_tide_resolve(caster: BattleCharacter, ultimate: Ultimate) -> void:
	for target in caster.enemies:
		var damage_value: float = target.hp_max * ultimate.effect_ratio
		var detail := "奧義「%s」生效:%s 受到生命上限(%d)的 %.0f%% = %.1f 傷害" % [
			ultimate.name, target.name, target.hp_max, ultimate.effect_ratio * 100.0, damage_value,
		]
		CombatResolver.apply_damage(target, damage_value, false, detail)
	_apply_resistible_mechanic_to_enemies(caster, GameEnums.SkillMechanic.SEAL, ultimate.duration_rounds)

## SS 深淵凝視:敵方全體受生命上限 effect_ratio(25%)傷害 + 陷入「恐懼」duration_rounds 回合。
static func abyssal_gaze_resolve(caster: BattleCharacter, ultimate: Ultimate) -> void:
	for target in caster.enemies:
		var damage_value: float = target.hp_max * ultimate.effect_ratio
		var detail := "奧義「%s」生效:%s 受到生命上限(%d)的 %.0f%% = %.1f 傷害" % [
			ultimate.name, target.name, target.hp_max, ultimate.effect_ratio * 100.0, damage_value,
		]
		CombatResolver.apply_damage(target, damage_value, false, detail)
	_apply_resistible_mechanic_to_enemies(caster, GameEnums.SkillMechanic.FEAR, ultimate.duration_rounds)

## SSS 終焉審判:敵方全體受生命上限 effect_ratio(35%)傷害 + 陷入「恐懼」duration_rounds
## 回合 + 額外陷入「封印」_FINAL_JUDGMENT_SEAL_ROUNDS(1)回合,三個效果一次到位的壓軸奧義。
const _FINAL_JUDGMENT_SEAL_ROUNDS := 1

static func final_judgment_resolve(caster: BattleCharacter, ultimate: Ultimate) -> void:
	for target in caster.enemies:
		var damage_value: float = target.hp_max * ultimate.effect_ratio
		var detail := "奧義「%s」生效:%s 受到生命上限(%d)的 %.0f%% = %.1f 傷害" % [
			ultimate.name, target.name, target.hp_max, ultimate.effect_ratio * 100.0, damage_value,
		]
		CombatResolver.apply_damage(target, damage_value, false, detail)
	_apply_resistible_mechanic_to_enemies(caster, GameEnums.SkillMechanic.FEAR, ultimate.duration_rounds)
	_apply_resistible_mechanic_to_enemies(caster, GameEnums.SkillMechanic.SEAL, _FINAL_JUDGMENT_SEAL_ROUNDS)
