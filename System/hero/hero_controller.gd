class_name HeroController
extends RefCounted

const MIN_AGE := 16
const MAX_AGE := 60

static func get_random_hero() -> Hero:
	var hero_name: String = Util.get_random_from_array(GameEnums.MALE_HERO_NAMES)
	var last_name: String = Util.get_random_from_array(GameEnums.MALE_HERO_LAST_NAMES)
	var age := Util.get_random_int(MIN_AGE, MAX_AGE + 1)
	var face_path := FaceController.get_random_face_path()
	var traits := TraitController.get_random_traits(2)
	var potential := PotentialController.get_random_potential()
	var skill_list := SkillController.get_random_skill_list()
	return Hero.new(hero_name, last_name, age, face_path, traits, potential, skill_list, LevelSystem.new())

# TODO(設計待定): 結婚/生子邏輯待「玩家間聯姻」系統設計確定後再實作(見企劃文件 二十二~三十二)
