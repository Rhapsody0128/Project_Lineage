class_name Character
extends RefCounted

## 血量上限與 battle_cost 佔位格數掛勾(見 BattleCostController 的 MIN_CELLS/MAX_CELLS),
## 格數越多站位越大,血量上限越高
const COST_HP_MAP := {
	3: 600,
	4: 700,
	5: 800,
	6: 900,
	7: 1000,
}

var id: String
var name: String
var last_name: String
var age: int
var gender: GameEnums.Gender
var face_path: String
var traits: Array[CharacterTrait]
var potential: Potential
var bloodline: Bloodline
## 高階血統(NOBLE)評分,GameEnums.RankType,見 _compute_noble_bloodline_rank()——
## 跟 Potential 的 xxx_rank 欄位同一套慣例:建立角色當下算好存欄位,不隨後續變動,
## UI 顯示端(CharacterDetailView 等)直接讀這個欄位,不自己再算一次。
var noble_bloodline_rank: int
## 目前手持的武器,決定哪些 bind_weapon 技能能施放
var weapon: GameEnums.WeaponType
var skill_list: Array[Skill]
var level_system: LevelSystem
var hp: int
## 婚姻/血緣資料,見 遊戲企劃設定總整理.md 二十二~三十一。目前只開欄位,
## 實際寫入邏輯(結婚/生子)留給呼叫端(見 System/event/castle/castle_tavern_event.gd),
## 這裡不做任何自動判斷。
var parent: Array[Character] = []
var mate: Character = null
var children: Array[Character] = []
## 懷孕狀態,見 PregnancyRule/WorldTimeEventLibrary——每月累積,滿
## PregnancyRule.MONTHS_TO_BIRTH 個月產下孩子後歸零。
var is_pregnant: bool = false
var pregnancy_months: int = 0
## 戰場佔位形狀(俄羅斯方塊式多格圖形),用於 PartyEdit 編成畫面的格子佔用判斷
var battle_cost: BattleCost

func _init(
	p_name: String,
	p_last_name: String,
	p_age: int,
	p_gender: GameEnums.Gender,
	p_face_path: String,
	p_traits: Array[CharacterTrait],
	p_potential: Potential,
	p_bloodline: Bloodline,
	p_weapon: GameEnums.WeaponType,
	p_skill_list: Array[Skill],
	p_level_system: LevelSystem,
	p_battle_cost: BattleCost
) -> void:
	id = Util.generate_uuid()
	name = p_name
	last_name = p_last_name
	age = p_age
	gender = p_gender
	face_path = p_face_path
	traits = p_traits
	potential = p_potential
	bloodline = p_bloodline
	noble_bloodline_rank = compute_noble_bloodline_rank(p_bloodline)
	weapon = p_weapon
	skill_list = p_skill_list
	level_system = p_level_system
	battle_cost = p_battle_cost
	hp = hp_max

## 高階血統評分:Bloodline.get_total_noble_percentage() 每 STEP(12.5)一階換算成
## GameEnums.RankType(E~SSS 共 8 階,STEP*8 剛好等於 Bloodline.TOTAL 上限),對照表見
## 遊戲企劃設定總整理.md:0~<12.5=E、12.5~<25=D、25~<37.5=C、37.5~<50=B、
## 50~<62.5=A、62.5~<75=S、75~<87.5=SS、87.5~100=SSS。公開(非底線開頭)是因為
## CharacterController/InheritanceController 建立角色時,battle_cost 格數要看
## 這個評分先算(見 BattleCostController.cells_for_noble_rank()),
## 必須在 Character 物件實際建立「之前」就拿得到,不能等 _init() 內部才算。
static func compute_noble_bloodline_rank(p_bloodline: Bloodline) -> int:
	var total := p_bloodline.get_total_noble_percentage()
	return mini(floori(total / Bloodline.STEP), GameEnums.RankType.SSS)

## 該技能目前是否能施放:未綁定特定武器(NO_WEAPON_BINDING)一律可用,綁了武器則要手持相符武器
func can_use_skill(skill: Skill) -> bool:
	return skill.bind_weapon == GameEnums.NO_WEAPON_BINDING or skill.bind_weapon == weapon

## 是否學會守護技能(Skill.is_guard_skill,武器仍要相符/未綁定)——用旗標而非顯示名稱
## 字串比對,重新命名技能不會悄悄讓守護判定失效。CombatResolver.resolve_guard() 用。
func knows_guard_skill() -> bool:
	for s in skill_list:
		if s.is_guard_skill and can_use_skill(s):
			return true
	return false

var full_name: String:
	get: return "%s·%s" % [name, last_name]

var hp_max: int:
	get: return COST_HP_MAP.get(battle_cost.cells.size(), 600)

var is_disabled: bool:
	get: return hp <= 0

func take_damage(damage_points: int) -> void:
	hp = maxi(hp - damage_points, 0)

func heal(amount: int) -> void:
	hp = mini(hp + amount, hp_max)

## 世界時間每跨過一天,所有角色固定回復的血量(見 WorldTimeEventLibrary)
const DAILY_HP_REGEN := 50

func regen_daily_hp() -> void:
	heal(DAILY_HP_REGEN)

## 結為配偶,雙向寫入 mate(資格判定見 MarriageRule.can_propose())
func marry(target_character: Character) -> void:
	mate = target_character
	target_character.mate = self

## 世界時間每跨過一年時呼叫(見 WorldTimeEventLibrary),年紀 +1。未滿成人隨機池
## 起始年齡(CharacterController.MIN_AGE)的角色一定是遺傳出生的小孩(一般隨機角色
## 一開始就是成人),年紀增長跨過 FaceController 的頭像級距時一併刷新 face_path;
## 剛好跨過 MIN_AGE 那一年額外從成人隨機池抽一張換上(僅此一次——已成年角色之後
## age 只會越來越大,不會再落回未成年區間,也不會每年重抽頭像)。
func age_up() -> void:
	age += 1
	if age < CharacterController.MIN_AGE:
		face_path = FaceController.get_child_face_path(age, gender)
	elif age == CharacterController.MIN_AGE:
		face_path = FaceController.get_random_face_path(gender)

## 進入懷孕狀態,月數從 0 起算(資格判定見 PregnancyRule.is_eligible(),呼叫端見
## WorldTimeEventLibrary._roll_new_pregnancies())
func start_pregnancy() -> void:
	is_pregnant = true
	pregnancy_months = 0

## 懷孕月數 +1,回傳是否已到分娩月數(PregnancyRule.MONTHS_TO_BIRTH)
func advance_pregnancy() -> bool:
	pregnancy_months += 1
	return pregnancy_months >= PregnancyRule.MONTHS_TO_BIRTH

## 生產:小孩由 InheritanceController.create_child() 依父母資料算出(遺傳公式集中在
## System/inheritance/,不寫在這裡),雙向寫入親子關係並重置懷孕狀態。回傳新生兒——
## 加入 CharacterRosterStore/發 NEWS 是全域註冊/播報,不是角色自身的規則,留給呼叫端
## (WorldTimeEventLibrary)處理。self 一定是母親(PregnancyRule.is_eligible() 限定
## gender == FEMALE 才能懷孕),mate 在懷孕當下已確保非 null,故不需要額外 null 分支。
func give_birth() -> Character:
	var child := InheritanceController.create_child(mate, self)
	var new_parents: Array[Character] = [self, mate]
	child.parent = new_parents
	children.append(child)
	mate.children.append(child)
	is_pregnant = false
	pregnancy_months = 0
	return child

func gain_exp(exp_amount: int) -> void:
	level_system.gain_exp(exp_amount)

func _get_real_potential(initial_potential: float, ratio: float) -> float:
	return initial_potential + ratio * level_system.potential_level_constant

var strength: float:
	get: return _get_real_potential(potential.strength, potential.strength_ratio)
var agility: float:
	get: return _get_real_potential(potential.agility, potential.agility_ratio)
var dexterity: float:
	get: return _get_real_potential(potential.dexterity, potential.dexterity_ratio)
var vitality: float:
	get: return _get_real_potential(potential.vitality, potential.vitality_ratio)
var intelligence: float:
	get: return _get_real_potential(potential.intelligence, potential.intelligence_ratio)
var mentality: float:
	get: return _get_real_potential(potential.mentality, potential.mentality_ratio)

func get_potential(potential_type: int) -> float:
	match potential_type:
		GameEnums.PotentialType.STRENGTH:
			return strength
		GameEnums.PotentialType.AGILITY:
			return agility
		GameEnums.PotentialType.DEXTERITY:
			return dexterity
		GameEnums.PotentialType.VITALITY:
			return vitality
		GameEnums.PotentialType.INTELLIGENCE:
			return intelligence
		GameEnums.PotentialType.MENTALITY:
			return mentality
		_:
			return 0.0

## 素質的成長評級(GameEnums.RankType,依 Potential 建立當下算好的 ratio 決定,
## 不隨等級變動),UI 顯示用,例如角色面板的雷達圖標籤。
func get_potential_rank(potential_type: int) -> int:
	match potential_type:
		GameEnums.PotentialType.STRENGTH:
			return potential.strength_rank
		GameEnums.PotentialType.AGILITY:
			return potential.agility_rank
		GameEnums.PotentialType.DEXTERITY:
			return potential.dexterity_rank
		GameEnums.PotentialType.VITALITY:
			return potential.vitality_rank
		GameEnums.PotentialType.INTELLIGENCE:
			return potential.intelligence_rank
		GameEnums.PotentialType.MENTALITY:
			return potential.mentality_rank
		_:
			return GameEnums.RankType.E
