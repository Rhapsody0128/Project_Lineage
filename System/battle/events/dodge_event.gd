class_name DodgeEvent
extends BattleEvent

var actor: BattleCharacter
var actor_name: String
var target: BattleCharacter
var target_name: String

## 完美迴避(PERFECT_DODGE 武器被動)觸發時的技能名稱;一般閃避(CombatResolver.
## judge_dodge())留空字串。battle.gd 依這個欄位是否為空,分流成兩種不同的閃避演出——
## 完美迴避要喊出招式名稱、播放跟一般閃避不同的動畫,讓玩家一眼看出這次不是單純的
## AGI/DEX 判定閃開,見 BattleUnitVisual.play_perfect_dodge_reaction()。
var skill_name: String

func _init(p_actor: BattleCharacter, p_target: BattleCharacter, p_detail: String = "", p_skill_name: String = "") -> void:
	super._init(GameEnums.BattleEventType.DODGE, p_detail)
	actor = p_actor
	actor_name = p_actor.name
	target = p_target
	target_name = p_target.name
	skill_name = p_skill_name
