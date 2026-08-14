class_name SkillBuilder
extends RefCounted

## 技能建構器:GDScript 自訂函式不支援具名參數,Skill 原本 14 個欄位的位置參數建構子
## 在 skill_library.gd 有 9 處呼叫,只能靠行內註解防呆,順序錯了會靜默編譯成功、
## 值全部對錯位。改用鏈式方法呼叫,拼字錯的話是找不到方法名的編譯期錯誤。
## 用法:SkillBuilder.new().name("火球術").skill_range(3)....build()

var _skill := Skill.new()

func name(value: String) -> SkillBuilder:
	_skill.name = value
	return self

func description(value: String) -> SkillBuilder:
	_skill.description = value
	return self

func rank(value: GameEnums.RankType) -> SkillBuilder:
	_skill.rank = value
	return self

func skill_range(value: int) -> SkillBuilder:
	_skill.skill_range = value
	return self

func area_shape(value: GameEnums.AreaShape) -> SkillBuilder:
	_skill.area_shape = value
	return self

func area_size(value: int) -> SkillBuilder:
	_skill.area_size = value
	return self

func effect_stat(value: GameEnums.PotentialType) -> SkillBuilder:
	_skill.effect_stat = value
	return self

func skill_type(value: GameEnums.SkillType) -> SkillBuilder:
	_skill.skill_type = value
	return self

func bind_weapon(value: GameEnums.WeaponType) -> SkillBuilder:
	_skill.bind_weapon = value
	return self

func leader_skill() -> SkillBuilder:
	_skill.is_leader_skill = true
	return self

## 被動技能:開戰時套用一次,不吃每回合行動骰選(見 Skill.is_passive)。
func passive() -> SkillBuilder:
	_skill.is_passive = true
	return self

## 守護技能(B. 守護):同時標記被動(反應式判定,不吃行動骰選)與 is_guard_skill
## (CombatResolver.resolve_guard() 辨識用旗標)。
func guard_skill() -> SkillBuilder:
	_skill.is_passive = true
	_skill.is_guard_skill = true
	return self

func base_chance(value: float) -> SkillBuilder:
	_skill.base_chance = value
	return self

func skill_ratio(value: float) -> SkillBuilder:
	_skill.skill_ratio = value
	return self

func action(value: Callable) -> SkillBuilder:
	_skill.action = value
	return self

func build() -> Skill:
	return _skill
