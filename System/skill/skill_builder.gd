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

func bind_weapon(value: int) -> SkillBuilder:
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

## BUFF/DEBUFF 技能實際施加素質修正的項目,見 Skill.buffed_potential_types 註解。
func buffed_stats(value: Array[int]) -> SkillBuilder:
	_skill.buffed_potential_types = value
	return self

## 被動技能專用:宣告「持有我的人對某個技能類型(GameEnums.SkillType)打起仗來的偏好」,
## 見 Skill.ai_weight_multipliers 註解。可以連續呼叫多次宣告好幾個類型。
func ai_weight_multiplier(for_skill_type: GameEnums.SkillType, multiplier: float) -> SkillBuilder:
	_skill.ai_weight_multipliers[for_skill_type] = multiplier
	return self

## 見 Skill.mechanics 註解,一次宣告這個技能掛的所有特殊效果標記。
func mechanics(value: Array[int]) -> SkillBuilder:
	_skill.mechanics = value
	return self

## 必中:無視迴避判定,見 Skill.true_hit 註解。
func true_hit() -> SkillBuilder:
	_skill.true_hit = true
	return self

## 二/三連擊,見 Skill.multi_strike_count 註解。
func multi_strike(count: int) -> SkillBuilder:
	_skill.multi_strike_count = count
	return self

## 這個技能造成的增益/減益/異常狀態持續幾回合,見 Skill.duration_rounds 註解。
func duration_rounds(value: int) -> SkillBuilder:
	_skill.duration_rounds = value
	return self

## 雙屬性乘區的第二項屬性與係數,見 Skill.secondary_stat/secondary_ratio 註解。
func secondary_stat(value: GameEnums.PotentialType, ratio: float) -> SkillBuilder:
	_skill.secondary_stat = value
	_skill.secondary_ratio = ratio
	return self

## DAMAGE_REDUCTION/LIMITED_EXECUTE_COUNTER 專用:只借用 secondary_ratio 欄位存 HP 門檻
## (以 hp_ratio 表示,0.0=無條件生效),不像 secondary_stat() 那樣連帶設定
## secondary_stat——這裡刻意不要有第二個攻擊屬性參與傷害計算,只是欄位重複利用,見
## CombatResolver._apply_damage_reduction()/SkillEffectLibrary.maybe_limited_execute_counter()。
func hp_threshold(value: float) -> SkillBuilder:
	_skill.secondary_ratio = value
	return self

## 血統限定,見 Skill.required_bloodline_nation/required_bloodline_rank 註解;rank 預設
## 高血(NOBLE),因為目前設計上的血統覺醒技一律限定高血才有機率習得。
func requires_bloodline(nation: GameEnums.BloodlineNation, bloodline_rank: GameEnums.BloodlineRank = GameEnums.BloodlineRank.NOBLE) -> SkillBuilder:
	_skill.required_bloodline_nation = nation
	_skill.required_bloodline_rank = bloodline_rank
	return self

func action(value: Callable) -> SkillBuilder:
	_skill.action = value
	return self

func build() -> Skill:
	return _skill
