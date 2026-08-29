class_name AttackEvent
extends BattleEvent

var actor: BattleCharacter
var actor_name: String
var target: BattleCharacter
var target_name: String

## 這次普通攻擊是被哪支被動技能觸發/擴大的:EXTRA_HIT_ON_ATTACK(追加一擊)讓 actor
## 額外多打一次時,這次多出來的攻擊就填該技能名稱;AREA_EXPAND_ON_ATTACK(範圍擴大)讓
## 這次攻擊波及更多目標時,同一筆 AttackEvent 也會填上——空字串代表單純的普通攻擊,沒有
## 被動介入。battle.gd 依這個欄位額外喊出招式名稱,見 BattleCharacter.attack()/
## _resolve_basic_attack_hit()。
var skill_name: String

func _init(p_actor: BattleCharacter, p_target: BattleCharacter, p_detail: String = "", p_skill_name: String = "") -> void:
	super._init(GameEnums.BattleEventType.ATTACK, p_detail)
	actor = p_actor
	actor_name = p_actor.name
	target = p_target
	target_name = p_target.name
	skill_name = p_skill_name
