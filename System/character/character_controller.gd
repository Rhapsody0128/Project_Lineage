class_name CharacterController
extends RefCounted

const MIN_AGE := 16
const MAX_AGE := 60

## 隨機發放的武器池:角色一定會持有武器,涵蓋所有 WeaponType。並列最高素質時
## get_weapon_for_potential() 從這個池子篩出的並列項目裡抽一個。
const RANDOM_WEAPON_POOL: Array[int] = [
	GameEnums.WeaponType.SWORD,
	GameEnums.WeaponType.BOW,
	GameEnums.WeaponType.SHIELD,
	GameEnums.WeaponType.DAGGER,
	GameEnums.WeaponType.STAFF,
	GameEnums.WeaponType.DREAMCATCHER,
]

## 武器→攻擊素質配對,對照 SkillEffectLibrary._attack_value():力量→劍、體質→盾、
## 敏捷→匕首、靈巧→弓、智慧→法杖、信仰→捕夢網(盾/匕首/捕夢網雖然是混合素質,但取
## 權重較高的那項當代表)。
const WEAPON_BY_PRIMARY_STAT := {
	GameEnums.WeaponType.SWORD: "strength",
	GameEnums.WeaponType.SHIELD: "vitality",
	GameEnums.WeaponType.DAGGER: "agility",
	GameEnums.WeaponType.BOW: "dexterity",
	GameEnums.WeaponType.STAFF: "intelligence",
	GameEnums.WeaponType.DREAMCATCHER: "mentality",
}

## 依角色六大素質中最高者發放對應武器,取代純隨機抽武器——武器決定攻擊素質輸出
## (見 SkillEffectLibrary._attack_value()),發武器前先看角色最擅長哪項素質,才能讓
## 戰鬥數值跟裝備直覺對應。並列最高時從並列項目裡隨機抽一個,避免固定偏向某一項。
static func get_weapon_for_potential(potential: Potential) -> int:
	var max_value := -1.0
	for weapon in WEAPON_BY_PRIMARY_STAT:
		max_value = max(max_value, potential.get(WEAPON_BY_PRIMARY_STAT[weapon]))
	var best_weapons: Array[int] = []
	for weapon in WEAPON_BY_PRIMARY_STAT:
		if potential.get(WEAPON_BY_PRIMARY_STAT[weapon]) == max_value:
			best_weapons.append(weapon)
	return Util.get_random_from_array(best_weapons)

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
	var weapon: int = get_weapon_for_potential(potential)
	var skill_list := SkillController.get_skill_list_by_weapon(weapon)
	var noble_rank := Character.compute_noble_bloodline_rank(bloodline)
	var battle_cost := BattleCostController.get_random_battle_cost(BattleCostController.cells_for_noble_rank(noble_rank))
	# 加上男女抽池子了
	return Character.new(character_name, last_name, age, gender, face_path, traits, potential, bloodline, weapon, skill_list, LevelSystem.new(), battle_cost)

## 玩家固定主角:遊戲開始時直接建立、免經 PartyEdit 就加入初始小隊(見
## main.gd 的 _ensure_starting_party())。姓名/年齡/性別/武器先用佔位資料寫死,
## 之後企劃資料確定再整段換掉;素質/血統/個性/技能/佔位格暫時仍沿用既有隨機池,
## 不影響「這個角色一開始就固定存在」這件事。
const PROTAGONIST_NAME := "威廉"
const PROTAGONIST_LAST_NAME := "華勒斯"
const PROTAGONIST_AGE := 49
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
	var protagonist := Character.new(PROTAGONIST_NAME, PROTAGONIST_LAST_NAME, PROTAGONIST_AGE, PROTAGONIST_GENDER, face_path, traits, potential, bloodline, PROTAGONIST_WEAPON, skill_list, LevelSystem.new(), battle_cost)
	protagonist.is_protagonist = true
	return protagonist

# TODO(設計待定): 結婚/生子邏輯待「玩家間聯姻」系統設計確定後再實作(見企劃文件 二十二~三十二)
