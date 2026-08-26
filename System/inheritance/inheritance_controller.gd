class_name InheritanceController
extends RefCounted

## 生小孩流程的遺傳計算總入口,取代 Character.give_birth() 原本呼叫的
## CharacterController.get_random_character() 占位邏輯。只有年齡/頭像/血統/潛力
## 四項照遺傳規則計算,姓名/特質/battle_cost 這些需求未涵蓋的欄位沿用
## CharacterController 既有的隨機規則,不額外變動——「生小孩」只負責建立 Character +
## 基本資料,實際遺傳公式全部委派給 BloodlineInheritance/PotentialInheritance/
## BloodlineLibrary,方便未來繼續疊加新的遺傳因素(特殊遺傳/突變等)。技能刻意留空
## (見下方 skill_list),小孩出生時不帶任何技能,之後靠「小孩慢慢學會技能」的流程逐步
## 習得(尚未設計,設計好後直接改這裡的 skill_list)。武器同樣刻意留空
## (GameEnums.NO_WEAPON_BINDING)——出生當下緊接著的命名+留學國家場景會決定角色未來的
## 武器方向(見 AcademyRule.enroll()),在那之前武器本來就還沒決定。

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
	var weapon := CharacterController.get_weapon_for_potential(potential)
	var noble_rank := Character.compute_noble_bloodline_rank(bloodline)
	# 出生時什麼技能都不會帶,之後靠「小孩慢慢學會技能」的流程逐步習得(尚未設計)。
	var skill_list: Array[Skill] = []
	var battle_cost := BattleCostController.get_random_battle_cost(BattleCostController.cells_for_noble_rank(noble_rank))

	return Character.new(character_name, last_name, age, gender, face_path, traits,
		potential, bloodline, weapon, skill_list, LevelSystem.new(), battle_cost)
