class_name StatEffectExpiredEvent
extends BattleEvent

## StatEffectEvent 的到期對照筆:duration_rounds 跑完(Battle._tick_status_effects())
## 或手動清除(BattleCharacter 各個 apply_*() 覆寫同一項修正時)才記一筆,is_buff 沿用
## 建構當下就已知的增益/減益方向,不重新從 multiplier 推導——因為修正到期時數值已經
## 被移除,這裡沒有 multiplier 可讀。

var target: BattleCharacter
var target_name: String
var potential_types: Array[int]
var is_buff: bool

func _init(p_target: BattleCharacter, p_potential_types: Array[int], p_is_buff: bool) -> void:
	super._init(GameEnums.BattleEventType.STAT_EFFECT_EXPIRED)
	target = p_target
	target_name = p_target.name
	potential_types = p_potential_types
	is_buff = p_is_buff
