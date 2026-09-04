class_name StatEffectEvent
extends BattleEvent

## 素質數值增益/減益套用當下記一筆(跟 StatusMechanicEvent 的旗標型狀態分開,見該檔案
## 開頭註解)。potential_types 用 Array[int] 而非 Array[GameEnums.PotentialType]——
## BUFF/DEBUFF 技能常同時套用多個素質(見 Skill.buffed_potential_types),這裡沿用
## 同一個型別慣例。is_buff 不是另外傳入的旗標,是建構時直接由 multiplier 正負推導
## (multiplier > 0.0),呼叫端不用自己判斷一次。rounds 對應 Skill.duration_rounds。

var target: BattleCharacter
var target_name: String
var potential_types: Array[int]
var multiplier: float
var rounds: int
var is_buff: bool

func _init(
	p_target: BattleCharacter, p_potential_types: Array[int], p_multiplier: float, p_rounds: int
) -> void:
	super._init(GameEnums.BattleEventType.STAT_EFFECT)
	target = p_target
	target_name = p_target.name
	potential_types = p_potential_types
	multiplier = p_multiplier
	rounds = p_rounds
	is_buff = p_multiplier > 0.0
