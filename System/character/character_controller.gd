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
	var character_name: String = Util.get_random_from_array(GameEnums.MALE_CHARACTER_NAMES)
	var last_name: String = Util.get_random_from_array(GameEnums.MALE_CHARACTER_LAST_NAMES)
	var age := Util.get_random_int(MIN_AGE, MAX_AGE + 1)
	var face_path := FaceController.get_random_face_path()
	var traits := TraitController.get_random_traits(2)
	var potential := PotentialController.get_random_potential()
	var bloodline := BloodlineController.get_random_bloodline()
	var weapon: int = Util.get_random_from_array(RANDOM_WEAPON_POOL)
	var skill_list := SkillController.get_skill_list_by_weapon(weapon)
	var battle_cost := BattleCostController.get_random_battle_cost()
	# 目前只有男性姓名庫(MALE_CHARACTER_NAMES),一律指派 MALE;女性角色池補上後這裡再隨機挑選。
	return Character.new(character_name, last_name, age, GameEnums.Gender.MALE, face_path, traits, potential, bloodline, weapon, skill_list, LevelSystem.new(), battle_cost)

# TODO(設計待定): 結婚/生子邏輯待「玩家間聯姻」系統設計確定後再實作(見企劃文件 二十二~三十二)
