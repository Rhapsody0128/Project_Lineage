class_name TickStatusResult
extends RefCounted

## BattleCharacter.tick_status_effects() 的回傳值:GDScript 沒有多回傳值,這裡把「這回合
## 到期的素質修正」跟「這回合到期的機制狀態(恐懼/封印/嘲諷/降治療/全隊限時破防&必定暴擊)」
## 分開兩個欄位,呼叫端(Battle._tick_status_effects())各自記對應的戰報事件
## (StatEffectExpiredEvent/StatusMechanicEvent)。

var expired_stat_modifiers: Array[StatModifier]
var expired_mechanics: Array[GameEnums.SkillMechanic]

func _init(p_expired_stat_modifiers: Array[StatModifier], p_expired_mechanics: Array[GameEnums.SkillMechanic]) -> void:
	expired_stat_modifiers = p_expired_stat_modifiers
	expired_mechanics = p_expired_mechanics
