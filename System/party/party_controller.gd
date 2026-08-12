class_name PartyController
extends RefCounted

static func get_random_party() -> Party:
	var hero := HeroController.get_random_hero()
	var soldiers: Array[Soldier] = []
	for i in range(5):
		soldiers.append(SoldierController.get_random_soldier())
	return Party.new(hero.name + "隊", hero, soldiers)
