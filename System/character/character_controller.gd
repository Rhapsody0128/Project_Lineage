class_name CharacterController
extends RefCounted

const MIN_AGE := 16
const MAX_AGE := 60

## 隨機發放的武器池:角色一定會持有武器,涵蓋所有 WeaponType
const RANDOM_WEAPON_POOL: Array[int] = [
	GameEnums.WeaponType.SWORD,
	GameEnums.WeaponType.BOW,
	GameEnums.WeaponType.SHIELD,
	GameEnums.WeaponType.DAGGER,
	GameEnums.WeaponType.STAFF,
	GameEnums.WeaponType.DREAMCATCHER,
]

static func get_random_character() -> Character:
	var gender = Util.get_random_from_array([GameEnums.Gender.MALE, GameEnums.Gender.FEMALE])
	var character_name: String
	if gender == GameEnums.Gender.MALE:
		character_name = Util.get_random_from_array(GameEnums.MALE_CHARACTER_NAMES)
	else:
		character_name = Util.get_random_from_array(GameEnums.FEMALE_CHARACTER_NAMES)
	var face_path := FaceController.get_random_face_path(gender)

	var last_name: String = Util.get_random_from_array(GameEnums.CHARACTER_LAST_NAMES)
	var age := Util.get_random_int(MIN_AGE, MAX_AGE + 1)
	var traits := TraitController.get_random_traits(2)
	var potential := PotentialController.get_random_potential()
	var bloodline := BloodlineController.get_random_bloodline()
	var weapon: int = Util.get_random_from_array(RANDOM_WEAPON_POOL)
	var skill_list := SkillController.get_skill_list_by_weapon(weapon)
	var battle_cost := BattleCostController.get_random_battle_cost()
	# 加上男女抽池子了
	return Character.new(character_name, last_name, age, gender, face_path, traits, potential, bloodline, weapon, skill_list, LevelSystem.new(), battle_cost)

# TODO(設計待定): 結婚/生子邏輯待「玩家間聯姻」系統設計確定後再實作(見企劃文件 二十二~三十二)
