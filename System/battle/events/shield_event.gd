class_name ShieldEvent
extends BattleEvent

## 護盾事件:跟 HealEvent 分開記錄——護盾是獨立於 HP 之外的緩衝血量
## (BattleCharacter.shield_points),不直接回復 HP,見 SkillEffectLibrary.shield()/
## CombatResolver.apply_damage() 的護盾吸收邏輯。Scenes 端目前沿用既有動畫(尚未有
## 專屬護盾視覺效果),之後要另外設計呈現方式時再接上。

var target: BattleCharacter
var target_name: String
var shield_points: int
var total_shield: int

func _init(p_target: BattleCharacter, p_shield_points: int, p_total_shield: int, p_detail: String = "") -> void:
	super._init(GameEnums.BattleEventType.SHIELD, p_detail)
	target = p_target
	target_name = p_target.name
	shield_points = p_shield_points
	total_shield = p_total_shield
