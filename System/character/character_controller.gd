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

## rank_type/nation 不填(-1)= 維持原本隨機生成(Bloodline Rank/Potential Rank/國家各自
## 獨立隨機);指定時整份 Bloodline/Potential 都依指定條件產生,見
## PotentialController.get_random_potential()/BloodlineController.get_random_bloodline()。
static func get_random_character(rank_type: int = -1, nation: int = -1) -> Character:
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
	var potential := PotentialController.get_random_potential(rank_type)
	var bloodline := BloodlineController.get_random_bloodline(rank_type, nation)
	var weapon: int = Util.get_random_from_array(RANDOM_WEAPON_POOL)
	var skill_list := SkillController.get_skill_list_by_weapon(weapon)
	var noble_rank := Character.compute_noble_bloodline_rank(bloodline)
	var battle_cost := BattleCostController.get_random_battle_cost(BattleCostController.cells_for_noble_rank(noble_rank))
	# 加上男女抽池子了
	return Character.new(character_name, last_name, age, gender, face_path, traits, potential, bloodline, weapon, skill_list, LevelSystem.new(), battle_cost)

## 玩家固定主角:遊戲開始時直接建立、免經 PartyEdit 就加入初始小隊(見
## main.gd 的 _ensure_starting_party())。姓名/年齡/性別/武器先用佔位資料寫死,
## 之後企劃資料確定再整段換掉;素質/血統/個性/技能/佔位格暫時仍沿用既有隨機池,
## 不影響「這個角色一開始就固定存在」這件事。
const PROTAGONIST_NAME := "主角"
const PROTAGONIST_LAST_NAME := "佔位姓氏"
const PROTAGONIST_AGE := 20
const PROTAGONIST_GENDER := GameEnums.Gender.MALE
const PROTAGONIST_WEAPON := GameEnums.WeaponType.SWORD

static func get_fixed_protagonist() -> Character:
	var face_path := FaceController.get_random_face_path(PROTAGONIST_GENDER)
	var traits := TraitController.get_random_traits(2)
	var potential := PotentialController.get_random_potential(GameEnums.RankType.F)
	var bloodline := BloodlineController.get_random_bloodline(GameEnums.RankType.F)
	var skill_list := SkillController.get_skill_list_by_weapon(PROTAGONIST_WEAPON)
	var noble_rank := Character.compute_noble_bloodline_rank(bloodline)
	var battle_cost := BattleCostController.get_random_battle_cost(BattleCostController.cells_for_noble_rank(noble_rank))
	return Character.new(PROTAGONIST_NAME, PROTAGONIST_LAST_NAME, PROTAGONIST_AGE, PROTAGONIST_GENDER, face_path, traits, potential, bloodline, PROTAGONIST_WEAPON, skill_list, LevelSystem.new(), battle_cost)

# TODO(設計待定): 結婚/生子邏輯待「玩家間聯姻」系統設計確定後再實作(見企劃文件 二十二~三十二)
