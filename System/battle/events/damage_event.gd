class_name DamageEvent
extends BattleEvent

var target: BattleCharacter
var target_name: String
var damage_points: int
var remaining_hp: int
var is_critical: bool
## 護盾吸收後剩餘的護盾值(見 CombatResolver.apply_damage()),給 BattlePartyRoster
## 的護盾條同步用——傷害可能消耗掉部分/全部護盾,單靠 ShieldEvent(只在護盾施放當下
## 記一次)沒辦法反映後續每次受傷的消耗進度。
var remaining_shield: int

## 減傷被動(DAMAGE_REDUCTION,絕境求生/身經百戰)這次有沒有發動、發動的技能名稱是
## 什麼;空字串代表沒有觸發。battle.gd 依這個欄位額外喊出招式名稱(見
## CombatResolver.apply_damage())。這是防禦方(target)自己的被動,跟下面
## actor/actor_proc_skill_names(攻擊方的被動)分開存,兩邊各自可能同時觸發、各自
## 對著各自的頭像喊。
var reduction_skill_name: String

## 造成這筆傷害的攻擊方(可能是 null——奧義等沒有明確單一攻擊者的傷害來源不填這個),
## 以及攻擊方這一擊順帶觸發的被動技能名稱清單(破綻洞察/絕殺直覺這類機率觸發、只影響
## 傷害數值本身、不會另外產生獨立攻擊動作的被動——有獨立動作的武器被動如反擊/完美迴避
## 走各自的事件類型,不會出現在這裡)。battle.gd 依序對 actor 的頭像喊出這些名稱,見
## CombatResolver.apply_damage()。
var actor: BattleCharacter
var actor_proc_skill_names: Array[String]

func _init(
	p_target: BattleCharacter, p_damage_points: int, p_remaining_hp: int,
	p_is_critical: bool = false, p_detail: String = "", p_remaining_shield: int = 0,
	p_reduction_skill_name: String = "", p_actor: BattleCharacter = null,
	p_actor_proc_skill_names: Array[String] = []
) -> void:
	super._init(GameEnums.BattleEventType.DAMAGE, p_detail)
	target = p_target
	target_name = p_target.name
	damage_points = p_damage_points
	remaining_hp = p_remaining_hp
	is_critical = p_is_critical
	remaining_shield = p_remaining_shield
	reduction_skill_name = p_reduction_skill_name
	actor = p_actor
	actor_proc_skill_names = p_actor_proc_skill_names
