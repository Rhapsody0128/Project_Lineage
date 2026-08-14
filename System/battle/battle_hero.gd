class_name BattleHero
extends RefCounted

## 戰場上一個角色的狀態容器:持有 Hero 參照、棋盤座標、buff/debuff、可用技能表,
## 並把「怎麼做」轉發給對應的服務類別——行動決策見 BattleAi、移動尋路見
## MovementPlanner、機率判定/傷害治療見 CombatResolver。BattleHero 自己不再寫演算法,
## 只做「持有狀態 + 記錄事件」。

var hero: Hero
var battle: Battle

## 是否為所屬小隊的隊長:戰場上顯示金色外框,陣亡會立即結束整場戰鬥
## (見 Battle.is_decided)
var is_leader: bool

var _is_enemy: bool

## 戰場格子座標,由 Battle 佈陣時指定初始值,戰鬥中隨 move() 更新
var grid_pos: Vector2i

## 可施放技能表:key 為技能 id,value 為權重(BattleAi.take_turn() 抽中 SKILL 時,
## 用這張表決定實際施放哪一個技能)。被動技能(is_passive)不會出現在這裡——
## 它們不是「選擇施放」,而是開戰時就套用/隨時反應觸發,見 _apply_passive_skills()。
var action_chance_map: Dictionary = {}

func _init(p_hero: Hero, p_battle: Battle, p_is_enemy: bool, p_is_leader: bool = false) -> void:
	hero = p_hero
	battle = p_battle
	_is_enemy = p_is_enemy
	is_leader = p_is_leader
	_set_action_chance()
	_apply_passive_skills()

## 只有手持武器與技能相符(或技能沒綁武器)、不是被動技能、且不是「不是隊長卻鎖 LEADER
## 技能」的情況,才能被抽到,權重直接採技能本身的基礎機率。
func _set_action_chance() -> void:
	for skill in hero.skill_list:
		if not hero.can_use_skill(skill):
			continue
		if skill.is_passive:
			continue
		if skill.is_leader_skill and not is_leader:
			continue
		action_chance_map[skill.id] = skill.base_chance

## 被動技能(A. 智勇兼備/B. 守護這類)不吃行動骰選,開戰當下就套用一次:被動技能的
## action Callable 簽名是 (self_hero, skill),沒有目標/cast_detail 的概念,見
## Skill.apply_passive()。B. 守護的效果其實不在這裡發生(它是反應式,見
## CombatResolver.resolve_guard()),這裡呼叫的效果函式只是佔位、不做事。
func _apply_passive_skills() -> void:
	for skill in hero.skill_list:
		if not skill.is_passive:
			continue
		if not hero.can_use_skill(skill):
			continue
		if skill.is_leader_skill and not is_leader:
			continue
		skill.apply_passive(self)

## 每回合的行動,決策邏輯交給 BattleAi。
func action() -> void:
	BattleAi.take_turn(self)

func find_skill_by_id(id: String) -> Skill:
	for s in hero.skill_list:
		if s.id == id:
			return s
	return null

## 普攻永遠是單體,出手前先過一次 CombatResolver.resolve_guard()——附近若有守護技能的
## 友軍願意頂替,實際受擊(閃避/暴擊/傷害判定全部換算)的對象就換成守護者,連戰報顯示的
## target 也一併換掉,動畫才會對準真正挨打的人。
func attack(target: BattleHero, action_detail: String = "") -> void:
	var guard_result := CombatResolver.resolve_guard(target, self)
	var actual_target: BattleHero = guard_result.target

	var target_pick_detail := "%s 鎖定距離最近的敵人 %s(距離 %d 格)作為普攻目標" % [
		name, target.name, Util.manhattan_distance(grid_pos, target.grid_pos),
	]
	var attack_detail := target_pick_detail
	if action_detail != "":
		attack_detail = "%s\n\n%s" % [action_detail, target_pick_detail]

	battle.log_event(AttackEvent.new(self, actual_target, attack_detail))

	var guarded: bool = actual_target != target
	var dodge_check: DodgeResult
	if guarded:
		# 守護的意義就是「用身體擋下來」,擋都擋了就不會再靈巧閃開,直接視為命中。
		dodge_check = DodgeResult.new(false, "%s 挺身守護,直接承受這次攻擊,不判定閃避" % actual_target.name)
	else:
		dodge_check = CombatResolver.judge_dodge(self, actual_target)
	if dodge_check.dodged:
		return
	var damage := SkillEffectLibrary.basic_attack_damage(self, actual_target, hero.weapon)
	var crit_check := CombatResolver.judge_crit(self, actual_target)
	if crit_check.critical:
		damage *= CombatResolver.CRIT_DAMAGE_MULTIPLIER
	var damage_detail := "%s\n\n%s" % [dodge_check.detail, crit_check.detail]
	if guarded:
		damage *= guard_result.damage_multiplier
		damage_detail += "\n\n此傷害因守護減少 30%"
	CombatResolver.apply_damage(actual_target, damage, crit_check.critical, damage_detail)

func daze(action_detail: String = "") -> void:
	battle.log_event(DazeEvent.new(self, action_detail))

## 往目標方向移動,實際路徑交給 MovementPlanner 計算,這裡只負責套用結果(移動棋盤格、
## 記一筆 move 事件)。整趟移動只記一筆 MoveEvent(內含完整路徑),讓畫面端可以連續
## 播放,不必每格都停頓。
func move(target: BattleHero, atk_range: int, action_detail: String = "") -> void:
	_move_towards_or_away(target, false, atk_range, action_detail)

## ESCAPE 類型用:往目標的反方向移動(遠離戰場)。max_range 預設 0,代表沒有距離上限、
## 盡量遠離戰場;遠程角色「退到最遠射程再出手」(kite_to_max_range)則會傳入該次攻擊/
## 技能的射程,一旦退到剛好等於射程就停止,不會白白退出射程外導致這次攻擊落空。
func move_away(target: BattleHero, max_range: int = 0, action_detail: String = "") -> void:
	_move_towards_or_away(target, true, max_range, action_detail)

## action_detail 是外層(BattleAi 的行動類型抽選)傳進來的說明前綴,可為空字串;
## 移動本身的公式(可走幾格/實際走了幾格/移動目的)一律自己組,不需要呼叫端提供。
func _move_towards_or_away(target: BattleHero, away: bool, atk_range: int, action_detail: String = "") -> void:
	var start_pos := grid_pos
	var path := MovementPlanner.plan_path(self, target, away, atk_range)

	if path.is_empty():
		return

	grid_pos = path[path.size() - 1]

	var purpose: String
	if away and atk_range > 0:
		purpose = "退到剛好等於射程 %d 格再出手,不會退出射程外" % atk_range
	elif away:
		purpose = "HP 剩 %.0f%%,觸發撤退,盡量遠離戰場拉開距離" % (hp_ratio * 100.0)
	else:
		purpose = "朝目標移動,進入距離 ≤ %d 格才會停止" % atk_range

	var move_steps := MovementPlanner.move_steps(self)
	var move_detail := (
		"%s %s %s,本回合最多可走 %d 格(基礎 %d ＋ 敏捷 %.1f ÷ 每 %.0f 點 +1 格),這次實際走了 %d 格\n" +
		"目的:%s"
	) % [
		name, ("遠離" if away else "接近"), target.name,
		move_steps, MovementPlanner.BASE_MOVE_STEPS, agility, MovementPlanner.AGILITY_PER_EXTRA_STEP,
		path.size(), purpose,
	]
	if action_detail != "":
		move_detail = "%s\n\n%s" % [action_detail, move_detail]

	battle.log_event(MoveEvent.new(self, target, start_pos, path, grid_pos, away, move_detail))

## 遠程攻擊(atk_range > 1)已經在射程內、但離目標比射程還近時,退到接近最遠射程再出手。
## 近戰(atk_range<=1)沒有後退空間,略過。
func kite_to_max_range(target: BattleHero, atk_range: int) -> void:
	if atk_range <= 1:
		return
	if Util.manhattan_distance(grid_pos, target.grid_pos) >= atk_range:
		return
	move_away(target, atk_range)

## 是否進入攻擊範圍(以格子曼哈頓距離判定):atk_range 由呼叫端決定——
## 普攻依武器種類(見 basic_attack_range),技能依技能自己的 skill_range。
func is_in_range(target: BattleHero, atk_range: int) -> bool:
	return Util.manhattan_distance(grid_pos, target.grid_pos) <= atk_range

## 基本攻擊距離:近戰武器(劍/盾/匕首)1 格、遠程武器(弓/法杖/捕夢網)2 格,
## 徒手(EMPTY)比照近戰
var basic_attack_range: int:
	get: return GameEnums.WEAPON_BASIC_ATTACK_RANGE[hero.weapon]

## 找尋最近的敵人(以格子曼哈頓距離判定)
func search_enemy() -> BattleHero:
	var best: BattleHero = null
	var best_dist := -1
	for other in enemies:
		var d := Util.manhattan_distance(grid_pos, other.grid_pos)
		if best == null or d < best_dist:
			best_dist = d
			best = other
	return best

## 敵人列表(存活中)
var enemies: Array[BattleHero]:
	get:
		var source: Array[BattleHero] = battle.self_heroes if _is_enemy else battle.enemy_heroes
		var result: Array[BattleHero] = []
		for p in source:
			if not p.is_disabled:
				result.append(p)
		return result

## 隊友列表(存活中,不含自己;CONFUSE 叛變攻擊用)
var allies: Array[BattleHero]:
	get:
		var source: Array[BattleHero] = battle.enemy_heroes if _is_enemy else battle.self_heroes
		var result: Array[BattleHero] = []
		for p in source:
			if p != self and not p.is_disabled:
				result.append(p)
		return result

var hp: int:
	get: return hero.hp

var hp_max: int:
	get: return hero.hp_max

## 目前 HP 比例(當前/最大),ESCAPE 是否列入抽選就看這個
var hp_ratio: float:
	get:
		if hp_max <= 0:
			return 0.0
		return float(hp) / float(hp_max)

var is_disabled: bool:
	get: return hero.is_disabled

var name: String:
	get: return hero.name

var is_enemy: bool:
	get: return _is_enemy

var _stat_modifiers: Array[StatModifier] = []

## 同一個(potential_type, multiplier)組合重複套用時只「續時」不疊加——例如 D. 大將之風
## 被同一個隊長連續好幾回合抽中重放,不會讓 +20% 力量一直往上疊加變成失控的天文數字,
## 只會把剩餘回合數重新刷回 rounds。不同 multiplier(例如同時中了 A 的永久 +30% 跟
## E 的 -20%)則各自是獨立一筆,會正常疊加抵銷。
func add_stat_modifier(potential_type: GameEnums.PotentialType, multiplier: float, rounds: int) -> void:
	for m in _stat_modifiers:
		if m.potential_type == potential_type and m.multiplier == multiplier:
			m.rounds_remaining = rounds
			return

	_stat_modifiers.append(StatModifier.new(potential_type, multiplier, rounds))

func _stat_modifier_multiplier(potential_type: GameEnums.PotentialType) -> float:
	var total := 0.0
	for m in _stat_modifiers:
		if m.potential_type == potential_type:
			total += m.multiplier
	return total

## 每回合結束時由 Battle._round_end() 呼叫:有時限的修正倒數 1 回合,歸零就移除;
## 永久修正(rounds_remaining < 0)不受影響。回傳這回合到期、需要顯示「效果解除」的
## 修正清單,給戰報 UI 用。
func tick_status_effects() -> Array[StatModifier]:
	var expired: Array[StatModifier] = []
	for m in _stat_modifiers.duplicate():
		if m.rounds_remaining < 0:
			continue
		m.rounds_remaining -= 1
		if m.rounds_remaining <= 0:
			_stat_modifiers.erase(m)
			expired.append(m)
	return expired

var strength: float:
	get: return hero.strength * (1.0 + _stat_modifier_multiplier(GameEnums.PotentialType.STRENGTH))
var agility: float:
	get: return hero.agility * (1.0 + _stat_modifier_multiplier(GameEnums.PotentialType.AGILITY))
var dexterity: float:
	get: return hero.dexterity * (1.0 + _stat_modifier_multiplier(GameEnums.PotentialType.DEXTERITY))
var vitality: float:
	get: return hero.vitality * (1.0 + _stat_modifier_multiplier(GameEnums.PotentialType.VITALITY))
var intelligence: float:
	get: return hero.intelligence * (1.0 + _stat_modifier_multiplier(GameEnums.PotentialType.INTELLIGENCE))
var mentality: float:
	get: return hero.mentality * (1.0 + _stat_modifier_multiplier(GameEnums.PotentialType.MENTALITY))

## 跟 Hero.get_potential() 對應,但回傳的是套用完戰場加成(裝備/等級皆含 Hero 本身
## 已算好的部分,再疊加 _stat_modifiers 的被動/主動技能、buff/debuff)之後的「即時」數值。
## UI(角色面板雷達圖)想顯示戰場當下的真實素質時用這個,不要直接讀 Hero.get_potential()。
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

## 行動速度(回合排序用),暫以敏捷做為速度來源
var action_speed: float:
	get: return agility
