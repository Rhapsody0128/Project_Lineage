class_name Skill
extends RefCounted

## 技能資料:數值/描述由 SkillBuilder 組裝(見 skill_library.gd),實際效果
## (數值計算/戰鬥表現)一律寫在 SkillEffectLibrary,透過 action 這個 Callable 帶入。

var id: String
var name: String
var description: String
var rank: GameEnums.RankType
## 施放距離(格數)。命名成 skill_range 而不是 range,避免蓋掉 GDScript 內建的 range()。
var skill_range: int
var area_shape: GameEnums.AreaShape
var area_size: int
var effect_stat: GameEnums.PotentialType
var skill_type: GameEnums.SkillType
## GameEnums.WeaponType 之一,或 GameEnums.NO_WEAPON_BINDING(任何武器都能用,例如被動/隊長技能)
var bind_weapon: int = GameEnums.NO_WEAPON_BINDING
var is_leader_skill: bool
## 被動技能:不會出現在 BattleCharacter.action_chance_map 裡供每回合骰選,而是開戰時
## 套用一次(見 BattleCharacter._apply_passive_skills()/apply_passive())。
## B. 守護這種「反應式」技能也算被動——它不是選出來主動施放的,只是效果不在
## apply_passive() 發生,而是 CombatResolver.resolve_guard() 隨時反應觸發。
var is_passive: bool
## 是否為守護技能(B. 守護):CombatResolver.resolve_guard()/Character.knows_guard_skill()
## 靠這個旗標辨識,不是顯示名稱字串比對——重新命名技能不會悄悄讓守護判定失效。
var is_guard_skill: bool
var base_chance: float
var skill_ratio: float
var action: Callable
## BUFF/DEBUFF 技能實際施加素質修正的項目(例如 D. 大將之風是 [STRENGTH, AGILITY,
## DEXTERITY]),SkillEffectLibrary 的 commander_bearing_buff()/curse_debuff() 直接讀
## 這個欄位施加,BattleAi 的骰選權重(見 _stat_skill_weight())也讀這個欄位判斷「這次
## 打得到的人是不是已經生效同一組修正了」,兩邊共用同一份資料,不會各自維護一份清單
## 兜到不一致。非 BUFF/DEBUFF 技能留空即可。
var buffed_potential_types: Array[int] = []

func _init() -> void:
	id = Util.generate_uuid()

## cast_detail 是施法前(選技能/選目標)的判定明細文字,原封不動轉交給 action 綁定的
## 效果 function,讓它併進最終 skill 事件的 detail 給戰報 UI 顯示。
func effect(self_character: BattleCharacter, target_character: BattleCharacter, cast_detail: String = "") -> void:
	if action.is_valid():
		action.call(self_character, target_character, self, cast_detail)

## 被動技能專用:開戰時套用一次,沒有目標/cast_detail 的概念,action 綁定的效果
## function 簽名固定是 (self_character, skill)。見 BattleCharacter._apply_passive_skills()。
func apply_passive(self_character: BattleCharacter) -> void:
	if action.is_valid():
		action.call(self_character, self)

## 依 area_shape/area_size 算出這次技能實際命中的目標(至少包含 primary_target 本身,
## ALL_ALLIES 除外)。候選名單依 skill_type 決定打誰(見 _candidate_pool()):
## ATTACK/DEBUFF 從敵方挑,BUFF/HEAL/DEFEND 從我方挑。
func resolve_targets(caster: BattleCharacter, primary_target: BattleCharacter) -> Array[BattleCharacter]:
	if area_shape == GameEnums.AreaShape.ALL_ALLIES:
		var result: Array[BattleCharacter] = caster.allies.duplicate()
		result.append(caster)
		return result

	var candidates: Array[BattleCharacter] = _candidate_pool(caster)
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
func _candidate_pool(caster: BattleCharacter) -> Array[BattleCharacter]:
	match skill_type:
		GameEnums.SkillType.BUFF, GameEnums.SkillType.HEAL, GameEnums.SkillType.DEFEND:
			return caster.allies
		_: # ATTACK, DEBUFF
			return caster.enemies

## 以命中目標為中心的菱形範圍(曼哈頓距離 ≤ area_size-1)
func _in_radius(candidates: Array[BattleCharacter], center: BattleCharacter) -> Array[BattleCharacter]:
	var result: Array[BattleCharacter] = []
	for c in candidates:
		if Util.manhattan_distance(c.grid_pos, center.grid_pos) <= area_size - 1:
			result.append(c)
	return result

## 以命中目標為中心的正方形範圍(切比雪夫距離 ≤ area_size-1)
func _in_square(candidates: Array[BattleCharacter], center: BattleCharacter) -> Array[BattleCharacter]:
	var result: Array[BattleCharacter] = []
	for c in candidates:
		var d: int = maxi(absi(c.grid_pos.x - center.grid_pos.x), absi(c.grid_pos.y - center.grid_pos.y))
		if d <= area_size - 1:
			result.append(c)
	return result

## 貫穿:同一列(grid_pos.y 相同),且落在「以 primary_target 為起點、往遠離施法者的
## 方向」延伸 area_size 格內(含 primary_target 自己)
func _in_line(candidates: Array[BattleCharacter], caster: BattleCharacter, primary_target: BattleCharacter) -> Array[BattleCharacter]:
	var dir := signi(primary_target.grid_pos.x - caster.grid_pos.x)
	if dir == 0:
		dir = 1

	var result: Array[BattleCharacter] = []
	for c in candidates:
		if c.grid_pos.y != primary_target.grid_pos.y:
			continue
		var offset: int = (c.grid_pos.x - primary_target.grid_pos.x) * dir
		if offset >= 0 and offset <= area_size - 1:
			result.append(c)
	return result
