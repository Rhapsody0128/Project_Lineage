class_name TroopController
extends RefCounted

static func get_random_troop() -> Troop:
	var parties: Array[Party] = []
	var formation := FormationController.get_random_formation()
	for i in range(6):
		var party := PartyController.get_random_party()
		var weapon := WeaponController.get_random_weapon()
		var formation_cell: FormationCell = formation.formation_cell_list[i]
		formation_cell.set_weapon(weapon)
		party.set_formation_cell(formation_cell)
		parties.append(party)
	return Troop.new("隨機軍團", parties, formation)
