class_name InheritanceController
extends RefCounted

## 生小孩流程的遺傳計算總入口,取代 Character.give_birth() 原本呼叫的
## CharacterController.get_random_character() 占位邏輯。只有年齡/頭像/血統/潛力
## 四項照遺傳規則計算,姓名/武器/技能/特質/battle_cost 這些需求未涵蓋的欄位沿用
## CharacterController 既有的隨機規則,不額外變動——「生小孩」只負責建立 Character +
## 基本資料,實際遺傳公式全部委派給 BloodlineInheritance/PotentialInheritance/
## BloodlineLibrary,方便未來繼續疊加新的遺傳因素(特殊遺傳/突變等)。

static func create_child(father: Character, mother: Character) -> Character:
	var gender: GameEnums.Gender = Util.get_random_from_array([GameEnums.Gender.MALE, GameEnums.Gender.FEMALE])
	var character_name: String
	if gender == GameEnums.Gender.MALE:
		character_name = Util.get_random_from_array(GameEnums.MALE_CHARACTER_NAMES)
	else:
		character_name = Util.get_random_from_array(GameEnums.FEMALE_CHARACTER_NAMES)
	var last_name: String = father.last_name
	var age := InheritanceConstants.CHILD_STARTING_AGE
	var face_path := FaceController.get_child_face_path(age, gender)

	var bloodline := BloodlineInheritance.inherit(father.bloodline, mother.bloodline)
	var potential := PotentialInheritance.inherit(father.potential, mother.potential)
	potential = BloodlineLibrary.apply_to_potential(potential, bloodline)

	var traits := TraitController.get_random_traits(2)
	var weapon: int = Util.get_random_from_array(CharacterController.RANDOM_WEAPON_POOL)
	var skill_list := SkillController.get_skill_list_by_weapon(weapon)
	var battle_cost := BattleCostController.get_random_battle_cost()

	return Character.new(character_name, last_name, age, gender, face_path, traits,
		potential, bloodline, weapon, skill_list, LevelSystem.new(), battle_cost)
