class_name DefeatedEvent
extends BattleEvent

var party: BattleHero
var party_name: String

func _init(p_party: BattleHero) -> void:
	super._init(GameEnums.BattleEventType.DEFEATED)
	party = p_party
	party_name = p_party.name

func to_debug_string() -> String:
	return "%s 戰敗" % party_name
