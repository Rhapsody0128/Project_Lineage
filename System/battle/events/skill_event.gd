class_name SkillEvent
extends BattleEvent

## actor 施放了一個主動技能(skill_name),target 是這次施放鎖定的目標——跟
## AttackEvent(普通攻擊)是平行的兩種事件類型,BattleAi 骰到的是攻擊還是技能決定
## 記哪一種。實際數值效果(傷害/治療/護盾/增益減益)另外各自記對應的 DamageEvent/
## HealEvent/ShieldEvent/StatEffectEvent,這裡只標記「這一次是哪個技能觸發的」,
## 讓 battle.gd 知道要不要在頭像旁喊出招式名稱。

var actor: BattleCharacter
var actor_name: String
var target: BattleCharacter
var target_name: String
var skill_name: String

func _init(p_actor: BattleCharacter, p_target: BattleCharacter, p_skill_name: String, p_detail: String = "") -> void:
	super._init(GameEnums.BattleEventType.SKILL, p_detail)
	actor = p_actor
	actor_name = p_actor.name
	target = p_target
	target_name = p_target.name
	skill_name = p_skill_name
