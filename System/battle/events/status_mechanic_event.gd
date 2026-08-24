class_name StatusMechanicEvent
extends BattleEvent

## 特殊狀態機制生效/解除(恐懼/封印/嘲諷/降治療/全隊限時破防&必定暴擊):跟
## StatEffectEvent(素質數值增減)分開記錄,因為這些是「有沒有中著」的旗標狀態,不是
## 素質數值——SkillEffectLibrary._apply_status_mechanics() 套用成功時記一筆
## is_active=true,BattleCharacter.cleanse_one_status()/Battle._tick_status_effects()
## 偵測到到期時記一筆 is_active=false,場景端(BattlePartyRoster/BattleUnitVisual)靠這個
## 決定要不要顯示狀態文字。

var target: BattleCharacter
var target_name: String
var mechanic: GameEnums.SkillMechanic
var is_active: bool

func _init(p_target: BattleCharacter, p_mechanic: GameEnums.SkillMechanic, p_is_active: bool, p_detail: String = "") -> void:
	super._init(GameEnums.BattleEventType.STATUS_MECHANIC, p_detail)
	target = p_target
	target_name = p_target.name
	mechanic = p_mechanic
	is_active = p_is_active
