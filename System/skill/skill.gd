class_name Skill
extends RefCounted

var id: String
var name: String
var description: String
var rank: int
var range: int
var area_shape: int
var area_size: int
var effect_stat: int
var skill_type: int
var bind_weapon: int
var is_leader_skill: bool
## 被動技能:不會出現在 BattleHero.action_chance_map 裡供每回合骰選,而是開戰時
## 套用一次(見 BattleHero._apply_passive_skills()/Skill.apply_passive())。
## B. 守護這種「反應式」技能也算被動——它不是選出來主動施放的,只是效果不在
## apply_passive() 發生,而是 BattleHero.resolve_guard() 隨時反應觸發。
var is_passive: bool
var base_chance: float
var skill_ratio: float
var action: Callable

func _init(
	p_name: String,
	p_description: String,
	p_rank: int,
	p_range: int,
	p_area_shape: int,
	p_area_size: int,
	p_effect_stat: int,
	p_skill_type: int,
	p_bind_weapon: int,
	p_is_leader_skill: bool,
	p_is_passive: bool,
	p_base_chance: float,
	p_skill_ratio: float,
	p_action: Callable
) -> void:
	id = Util.generate_uuid()
	name = p_name
	description = p_description
	rank = p_rank
	range = p_range
	area_shape = p_area_shape
	area_size = p_area_size
	effect_stat = p_effect_stat
	skill_type = p_skill_type
	bind_weapon = p_bind_weapon
	is_leader_skill = p_is_leader_skill
	is_passive = p_is_passive
	base_chance = p_base_chance
	skill_ratio = p_skill_ratio
	action = p_action

## cast_detail 是施法前(選技能/選目標)的判定明細文字,原封不動轉交給 action 綁定的
## 效果 function,讓它併進最終 skill 事件的 detail 給戰報 UI 顯示。
func effect(self_party, target_party, cast_detail: String = "") -> void:
	if action.is_valid():
		action.call(self_party, target_party, self, cast_detail)

## 被動技能專用:開戰時套用一次,沒有目標/cast_detail 的概念,action 綁定的效果
## function 簽名固定是 (self_hero, skill)。見 BattleHero._apply_passive_skills()。
func apply_passive(self_hero) -> void:
	if action.is_valid():
		action.call(self_hero, self)

## 依 area_shape/area_size 算出這次技能實際命中的目標(至少包含 primary_target 本身,
## ALL_ALLIES 除外)。候選名單依 skill_type 決定打誰(見 _candidate_pool()):
## ATTACK/DEBUFF 從敵方挑,BUFF/HEAL/DEFEND 從我方挑。
func resolve_targets(caster: BattleHero, primary_target: BattleHero) -> Array[BattleHero]:
	if area_shape == GameEnums.AreaShape.ALL_ALLIES:
		var result: Array[BattleHero] = caster.allies.duplicate()
		result.append(caster)
		return result

	var candidates: Array[BattleHero] = _candidate_pool(caster)
	match area_shape:
		GameEnums.AreaShape.RADIUS:
			return _in_radius(candidates, primary_target)
		GameEnums.AreaShape.LINE:
			return _in_line(candidates, caster, primary_target)
		GameEnums.AreaShape.SQUARE:
			return _in_square(candidates, primary_target)
		_: # SINGLE
			return [primary_target]

## ATTACK/DEBUFF 打敵方(caster.enemies);BUFF/HEAL/DEFEND 打我方(caster.allies,
## 不含施法者自己——ALL_ALLIES 那種「連自己也算」的全隊技能不會走到這裡,
## 上面 resolve_targets() 已經另外處理)。
func _candidate_pool(caster: BattleHero) -> Array[BattleHero]:
	match skill_type:
		GameEnums.SkillType.BUFF, GameEnums.SkillType.HEAL, GameEnums.SkillType.DEFEND:
			return caster.allies
		_: # ATTACK, DEBUFF
			return caster.enemies

## 以命中目標為中心的菱形範圍(曼哈頓距離 ≤ area_size-1)
func _in_radius(candidates: Array[BattleHero], center: BattleHero) -> Array[BattleHero]:
	var result: Array[BattleHero] = []
	for c in candidates:
		var d: int = abs(c.grid_pos.x - center.grid_pos.x) + abs(c.grid_pos.y - center.grid_pos.y)
		if d <= area_size - 1:
			result.append(c)
	return result

## 以命中目標為中心的正方形範圍(切比雪夫距離 ≤ area_size-1)
func _in_square(candidates: Array[BattleHero], center: BattleHero) -> Array[BattleHero]:
	var result: Array[BattleHero] = []
	for c in candidates:
		var d: int = maxi(absi(c.grid_pos.x - center.grid_pos.x), absi(c.grid_pos.y - center.grid_pos.y))
		if d <= area_size - 1:
			result.append(c)
	return result

## 貫穿:同一列(grid_pos.y 相同),且落在「以 primary_target 為起點、往遠離施法者的
## 方向」延伸 area_size 格內(含 primary_target 自己)
func _in_line(candidates: Array[BattleHero], caster: BattleHero, primary_target: BattleHero) -> Array[BattleHero]:
	var dir := signi(primary_target.grid_pos.x - caster.grid_pos.x)
	if dir == 0:
		dir = 1

	var result: Array[BattleHero] = []
	for c in candidates:
		if c.grid_pos.y != primary_target.grid_pos.y:
			continue
		var offset: int = (c.grid_pos.x - primary_target.grid_pos.x) * dir
		if offset >= 0 and offset <= area_size - 1:
			result.append(c)
	return result
