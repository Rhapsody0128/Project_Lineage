class_name DefeatedEvent
extends BattleEvent

## 單一角色 HP 歸零戰敗,見 CombatResolver.apply_damage() 傷害結算後的判定。
## 欄位命名是 party 不是 character——這裡的 party 指的仍是「這一個 BattleCharacter」,
## 不是 Party/小隊整體,沿用既有命名不改,避免無謂改動範圍。

var party: BattleCharacter
var party_name: String

func _init(p_party: BattleCharacter) -> void:
	super._init(GameEnums.BattleEventType.DEFEATED)
	party = p_party
	party_name = p_party.name
