class_name Hero
extends RefCounted

## 角色目前統一固定血量上限,尚未有依素質/等級計算血量的公式,先寫死
const HP_MAX := 600

var id: String
var name: String
var last_name: String
var age: int
var face_path: String
var traits: Array[CharacterTrait]
var potential: Potential
## 目前手持的武器(GameEnums.WeaponType),決定哪些 bind_weapon 技能能施放
var weapon: int
var skill_list: Array[Skill]
var level_system: LevelSystem
var hp: int

func _init(
	p_name: String,
	p_last_name: String,
	p_age: int,
	p_face_path: String,
	p_traits: Array[CharacterTrait],
	p_potential: Potential,
	p_weapon: int,
	p_skill_list: Array[Skill],
	p_level_system: LevelSystem
) -> void:
	id = Util.generate_uuid()
	name = p_name
	last_name = p_last_name
	age = p_age
	face_path = p_face_path
	traits = p_traits
	potential = p_potential
	weapon = p_weapon
	skill_list = p_skill_list
	level_system = p_level_system
	hp = HP_MAX

## 該技能目前是否能施放:未綁武器(EMPTY)一律可用,綁了武器則要手持相符武器
func can_use_skill(skill: Skill) -> bool:
	return skill.bind_weapon == GameEnums.WeaponType.EMPTY or skill.bind_weapon == weapon

var full_name: String:
	get: return "%s·%s" % [name, last_name]

var hp_max: int:
	get: return HP_MAX

var is_disabled: bool:
	get: return hp <= 0

func take_damage(damage_points: int) -> void:
	hp = maxi(hp - damage_points, 0)

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
