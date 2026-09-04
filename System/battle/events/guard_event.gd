class_name GuardEvent
extends BattleEvent

## 守護技能(B. 守護,見 Character.knows_guard_skill())觸發:actor 是飛身頂替的
## 守護者,target 是原本被鎖定的受害者,attacker 是發動攻擊的一方——三者都不同人,
## 傷害實際會改記在 actor 身上而非 target,見 CombatResolver.resolve_guard()。
## skill_name 目前固定是「捨身掩護」(唯一的守護技能),見 combat_resolver.gd 呼叫端。

var actor: BattleCharacter
var actor_name: String
var target: BattleCharacter
var target_name: String
var attacker: BattleCharacter
var attacker_name: String
var skill_name: String

func _init(
	p_actor: BattleCharacter, p_target: BattleCharacter, p_attacker: BattleCharacter,
	p_skill_name: String, p_detail: String = ""
) -> void:
	super._init(GameEnums.BattleEventType.GUARD, p_detail)
	actor = p_actor
	actor_name = p_actor.name
	target = p_target
	target_name = p_target.name
	attacker = p_attacker
	attacker_name = p_attacker.name
	skill_name = p_skill_name
