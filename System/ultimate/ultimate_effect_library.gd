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
