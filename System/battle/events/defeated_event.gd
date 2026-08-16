class_name DefeatedEvent
extends BattleEvent

var party: BattleCharacter
var party_name: String

func _init(p_party: BattleCharacter) -> void:
	super._init(GameEnums.BattleEventType.DEFEATED)
	party = p_party
	party_name = p_party.name
