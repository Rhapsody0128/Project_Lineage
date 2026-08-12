class_name BattleController
extends RefCounted

static func get_random_battle() -> Battle:
	var self_troop := TroopController.get_random_troop()
	var enemy_troop := TroopController.get_random_troop()
	return Battle.new(self_troop, enemy_troop)
