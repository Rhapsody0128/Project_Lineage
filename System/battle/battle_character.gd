class_name BattleCharacter
extends RefCounted

## 戰場上一個角色的狀態容器:持有 Character 參照、棋盤座標、buff/debuff、可用技能表,
## 並把「怎麼做」轉發給對應的服務類別——行動決策見 BattleAi、移動尋路見
## MovementPlanner、機率判定/傷害治療見 CombatResolver。BattleCharacter 自己不再寫演算法,
## 只做「持有狀態 + 記錄事件」。

var character: Character
var battle: Battle

## 是否為所屬小隊的隊長:戰場上顯示黃色遮罩,陣亡會立即結束整場戰鬥
## (見 Battle.is_decided)
var is_leader: bool

var _is_enemy: bool

## 戰場格子座標,由 Battle 佈陣時指定初始值,戰鬥中隨 move() 更新
var grid_pos: Vector2i

## 可施放技能表:key 為技能 id,value 為權重(BattleAi.take_turn() 抽中 SKILL 時,
## 用這張表決定實際施放哪一個技能)。被動技能(is_passive)不會出現在這裡——
## 它們不是「選擇施放」,而是開戰時就套用/隨時反應觸發,見 _apply_passive_skills()。
var action_chance_map: Dictionary = {}

func _init(p_character: Character, p_battle: Battle, p_is_enemy: bool, p_is_leader: bool = false) -> void:
	character = p_character
	battle = p_battle
	_is_enemy = p_is_enemy
	is_leader = p_is_leader
	_set_action_chance()
	_apply_passive_skills()
	_apply_morale_stat_modifier()
	# 永久被動(rounds_remaining < 0)從開戰第一刻就生效、整場不會被移除,兩份清單
	# 直接同步一次即可;之後的限時 buff/debuff 才需要靠重播事件逐步增減(見上方
	# _replay_stat_modifiers 註解)。
	_replay_stat_modifiers = _stat_modifiers.duplicate()

## 開戰當下把 MoraleStore 目前的士氣換算成全素質永久加成/減益(rounds=-1,整場戰鬥
## 不會過期),跟被動技能的永久 buff 走同一套 StatModifier 機制(見 strength/agility/…
## getter 讀的 _stat_modifier_multiplier())。只套用在玩家自己這一側——士氣是
## CHARACTER_ROSTER 整體狀態,不代表敵方小隊,見 Scripts/Autoload/morale_store.gd。
## 乘數為 0(士氣「普通」40~59 區間)時不寫入任何 StatModifier,維持跟沒有這個系統時
## 完全一致的行為。
func _apply_morale_stat_modifier() -> void:
	if _is_enemy:
		return
	var multiplier := MoraleRule.combat_stat_multiplier(MoraleStore.value)
	if is_equal_approx(multiplier, 0.0):
		return
	for potential_type in GameEnums.PotentialType.values():
		add_stat_modifier(potential_type, multiplier, -1)

## 只有手持武器與技能相符(或技能沒綁武器)、不是被動技能、且不是「不是隊長卻鎖 LEADER
## 技能」的情況,才能被抽到,權重直接採技能本身的基礎機率。
func _set_action_chance() -> void:
	for skill in character.skill_list:
		if not character.can_use_skill(skill):
			continue
		if skill.is_passive:
			continue
		if skill.is_leader_skill and not is_leader:
			continue
		action_chance_map[skill.id] = skill.base_chance

## 被動技能(A. 智勇兼備/B. 守護這類)不吃行動骰選,開戰當下就套用一次:被動技能的
## action Callable 簽名是 (self_character, skill),沒有目標/cast_detail 的概念,見
## Skill.apply_passive()。B. 守護的效果其實不在這裡發生(它是反應式,見
## CombatResolver.resolve_guard()),這裡呼叫的效果函式只是佔位、不做事。
func _apply_passive_skills() -> void:
	for skill in character.skill_list:
		if not skill.is_passive:
			continue
		if not character.can_use_skill(skill):
			continue
		if skill.is_leader_skill and not is_leader:
			continue
		skill.apply_passive(self)

## 每回合的行動,決策邏輯交給 BattleAi。
func action() -> void:
	BattleAi.take_turn(self)

func find_skill_by_id(id: String) -> Skill:
	for s in character.skill_list:
		if s.id == id:
			return s
	return null

## 依角色目前持有的被動技能宣告的 AI 傾向,算出「這個技能類型(GameEnums.SkillType)」
## 的權重乘數——見 Skill.ai_weight_multipliers 註解。多個被動各自宣告同一類型時連乘,
## 不是取代;沒有任何被動宣告這個類型時乘數是 1.0,不影響任何行為。BattleAi 骰選技能時
## 在情境加權之後再乘上這個(見 BattleAi._build_action_chance_map())。
func ai_personality_multiplier(skill_type: int) -> float:
	var multiplier := 1.0
	for skill in character.skill_list:
		if not skill.is_passive:
			continue
		if not character.can_use_skill(skill):
			continue
		if skill.ai_weight_multipliers.has(skill_type):
			multiplier *= skill.ai_weight_multipliers[skill_type]
	return multiplier

## 普攻鎖定 target,出手前先過一次 CombatResolver.resolve_guard()——附近若有守護技能的
## 友軍願意頂替,實際受擊(閃避/暴擊/傷害判定全部換算)的對象就換成守護者,連戰報顯示的
## target 也一併換掉,動畫才會對準真正挨打的人。額外接了兩個「只作用於普通攻擊,不影響
## 武器主動技」的武器被動機制(見 GameEnums.SkillMechanic 對應註解):
## AREA_EXPAND_ON_ATTACK 讓這次攻擊機率擴大成命中目標周遭範圍 1 格內的敵人;
## EXTRA_HIT_ON_ATTACK 命中後機率追加一次普通攻擊——allow_extra_hit 參數防止追加的
## 那一擊自己又觸發追加,避免無限連鎖(遞迴呼叫 attack() 時傳 false)。守護只保護
## target 本人,範圍擴大額外命中的敵人不會觸發守護。trigger_skill_name 是遞迴呼叫用:
## EXTRA_HIT_ON_ATTACK 觸發追加一擊時,把觸發的被動技能名稱傳進來,讓這筆額外的
## AttackEvent 也能喊出招式名稱(見下方 skill_event_names 組裝)。
func attack(target: BattleCharacter, action_detail: String = "", allow_extra_hit: bool = true, trigger_skill_name: String = "") -> void:
	var guard_result := CombatResolver.resolve_guard(target, self)
	var actual_target: BattleCharacter = guard_result.target
	var guarded: bool = actual_target != target

	var attack_targets: Array[BattleCharacter] = [actual_target]
	var expand_note := ""
	var event_skill_names: Array[String] = []
	if trigger_skill_name != "":
		event_skill_names.append(trigger_skill_name)
	var area_expand_skill := character.find_skill_with_mechanic(GameEnums.SkillMechanic.AREA_EXPAND_ON_ATTACK)
	if area_expand_skill != null and not guarded:
		var expand_trigger := CombatResolver.judge_reactive_trigger(name, area_expand_skill.base_chance)
		expand_note = "\n\n被動技能「%s」判定:\n%s" % [area_expand_skill.name, expand_trigger.detail]
		if expand_trigger.triggered:
			event_skill_names.append(area_expand_skill.name)
			for other in enemies:
				if other != actual_target and Util.manhattan_distance(other.grid_pos, actual_target.grid_pos) <= 1:
					attack_targets.append(other)

	var target_pick_detail := "%s 鎖定距離最近的敵人 %s(距離 %d 格)作為普攻目標%s" % [
		name, target.name, Util.manhattan_distance(grid_pos, target.grid_pos), expand_note,
	]
	var attack_detail := target_pick_detail
	if action_detail != "":
		attack_detail = "%s\n\n%s" % [action_detail, target_pick_detail]

	battle.log_event(AttackEvent.new(self, actual_target, attack_detail, "、".join(event_skill_names)))

	for hit_target in attack_targets:
		_resolve_basic_attack_hit(hit_target, guarded, guard_result.damage_multiplier, allow_extra_hit)

## 單次普通攻擊命中判定,見 attack() 對完美迴避/反擊/反應治療/追加一擊這幾個武器被動
## 機制的說明。guarded 只對 attack_targets 裡的第一個(真正被鎖定的 target,或頂替的
## 守護者)成立,範圍擴大額外命中的目標一律不觸發守護、正常判定閃避。
func _resolve_basic_attack_hit(actual_target: BattleCharacter, guarded: bool, guard_damage_multiplier: float, allow_extra_hit: bool) -> void:
	var dodge_check: DodgeResult
	if guarded:
		# 守護的意義就是「用身體擋下來」,擋都擋了就不會再靈巧閃開,直接視為命中。
		dodge_check = DodgeResult.new(false, "%s 挺身守護,直接承受這次攻擊,不判定閃避" % actual_target.name)
	else:
		var perfect_dodge_skill := actual_target.character.find_skill_with_mechanic(GameEnums.SkillMechanic.PERFECT_DODGE)
		if perfect_dodge_skill != null:
			var perfect_check := CombatResolver.judge_reactive_trigger(actual_target.name, perfect_dodge_skill.base_chance)
			var perfect_detail := "完美迴避判定:\n%s" % perfect_check.detail
			dodge_check = DodgeResult.new(perfect_check.triggered, perfect_detail)
			if perfect_check.triggered:
				battle.log_event(DodgeEvent.new(self, actual_target, perfect_detail, perfect_dodge_skill.name))
		else:
			dodge_check = DodgeResult.new(false, "")
		if not dodge_check.dodged:
			dodge_check = CombatResolver.judge_dodge(self, actual_target)
	if dodge_check.dodged:
		SkillEffectLibrary.maybe_dodge_counter(actual_target, self)
		return

	var proc_skill_names: Array[String] = []
	var armor_pierce := SkillEffectLibrary.check_chance_armor_pierce(self)
	var damage := SkillEffectLibrary.basic_attack_damage(self, actual_target, character.weapon, armor_pierce)
	var crit_check := CombatResolver.judge_crit(self, actual_target)
	if SkillEffectLibrary.check_chance_guaranteed_crit(self):
		if is_guaranteed_crit:
			crit_check = CritResult.new(true, "%s 的被動使這次攻擊必定暴擊" % name)
		else:
			var crit_skill := character.find_skill_with_mechanic(GameEnums.SkillMechanic.CHANCE_GUARANTEED_CRIT)
			crit_check = CritResult.new(true, "%s 發動被動技能「%s」,這次攻擊必定暴擊" % [name, crit_skill.name])
			proc_skill_names.append(crit_skill.name)
	if crit_check.critical:
		damage *= CombatResolver.crit_damage_multiplier()
	var armor_pierce_detail := ""
	if armor_pierce and not is_armor_piercing:
		var armor_pierce_skill := character.find_skill_with_mechanic(GameEnums.SkillMechanic.CHANCE_ARMOR_PIERCE)
		armor_pierce_detail = "\n\n%s 發動被動技能「%s」,這次攻擊無視防禦" % [name, armor_pierce_skill.name]
		proc_skill_names.append(armor_pierce_skill.name)
	var damage_detail := "%s\n\n%s%s" % [dodge_check.detail, crit_check.detail, armor_pierce_detail]
	if guarded:
		damage *= guard_damage_multiplier
		damage_detail += "\n\n此傷害因守護減少 30%"
	CombatResolver.apply_damage(actual_target, damage, crit_check.critical, damage_detail, self, proc_skill_names)

	SkillEffectLibrary.maybe_counter_attack(self, actual_target)
	SkillEffectLibrary.maybe_reactive_heal(actual_target)
	SkillEffectLibrary.maybe_kill_momentum(self, actual_target)
	SkillEffectLibrary.maybe_limited_execute_counter(actual_target, self)

	if not allow_extra_hit:
		return
	var extra_hit_skill := character.find_skill_with_mechanic(GameEnums.SkillMechanic.EXTRA_HIT_ON_ATTACK)
	if extra_hit_skill == null:
		return
	var extra_trigger := CombatResolver.judge_reactive_trigger(name, extra_hit_skill.base_chance)
	if extra_trigger.triggered:
		var extra_detail := "%s 發動被動技能「%s」,獲得追加一擊！\n%s" % [name, extra_hit_skill.name, extra_trigger.detail]
		attack(actual_target, extra_detail, false, extra_hit_skill.name)

func daze(action_detail: String = "") -> void:
	battle.log_event(DazeEvent.new(self, action_detail))

## 往目標方向移動,實際路徑交給 MovementPlanner 計算,這裡只負責套用結果(移動棋盤格、
## 記一筆 move 事件)。整趟移動只記一筆 MoveEvent(內含完整路徑),讓畫面端可以連續
## 播放,不必每格都停頓。
func move(target: BattleCharacter, atk_range: int, action_detail: String = "") -> void:
	_move_towards_or_away(target, false, atk_range, action_detail)

## ESCAPE 類型用:往目標的反方向移動(遠離戰場)。max_range 預設 0,代表沒有距離上限、
## 盡量遠離戰場;遠程角色「退到最遠射程再出手」(kite_to_max_range)則會傳入該次攻擊/
## 技能的射程,一旦退到剛好等於射程就停止,不會白白退出射程外導致這次攻擊落空。
func move_away(target: BattleCharacter, max_range: int = 0, action_detail: String = "") -> void:
	_move_towards_or_away(target, true, max_range, action_detail)

## action_detail 是外層(BattleAi 的行動類型抽選)傳進來的說明前綴,可為空字串;
## 移動本身的公式(可走幾格/實際走了幾格/移動目的)一律自己組,不需要呼叫端提供。
func _move_towards_or_away(target: BattleCharacter, away: bool, atk_range: int, action_detail: String = "") -> void:
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
func kite_to_max_range(target: BattleCharacter, atk_range: int) -> void:
	if atk_range <= 1:
		return
	if Util.manhattan_distance(grid_pos, target.grid_pos) >= atk_range:
		return
	move_away(target, atk_range)

## 是否進入攻擊範圍(以格子曼哈頓距離判定):atk_range 由呼叫端決定——
## 普攻依武器種類(見 basic_attack_range),技能依技能自己的 skill_range。
func is_in_range(target: BattleCharacter, atk_range: int) -> bool:
	return Util.manhattan_distance(grid_pos, target.grid_pos) <= atk_range

## 基本攻擊距離:近戰武器(劍/盾/匕首)1 格、遠程武器(弓/法杖/捕夢網)2 格
var basic_attack_range: int:
	get: return GameEnums.WEAPON_BASIC_ATTACK_RANGE[character.weapon]

## 找尋最近的敵人(以格子曼哈頓距離判定)——嘲諷中(taunted_by 不是 null 且對象還存活)
## 強制回傳嘲諷來源,不管距離遠近,見 BattleCharacter.apply_taunt()。
func search_enemy() -> BattleCharacter:
	if taunted_by != null and not taunted_by.is_disabled:
		return taunted_by

	var best: BattleCharacter = null
	var best_dist := -1
	for other in enemies:
		var d := Util.manhattan_distance(grid_pos, other.grid_pos)
		if best == null or d < best_dist:
			best_dist = d
			best = other
	return best

## 敵人列表(存活中)
var enemies: Array[BattleCharacter]:
	get:
		var source: Array[BattleCharacter] = battle.self_characteres if _is_enemy else battle.enemy_characteres
		var result: Array[BattleCharacter] = []
		for p in source:
			if not p.is_disabled:
				result.append(p)
		return result

## 隊友列表(存活中,不含自己;CONFUSE 叛變攻擊用)
var allies: Array[BattleCharacter]:
	get:
		var source: Array[BattleCharacter] = battle.enemy_characteres if _is_enemy else battle.self_characteres
		var result: Array[BattleCharacter] = []
		for p in source:
			if p != self and not p.is_disabled:
				result.append(p)
		return result

var hp: int:
	get: return character.hp

var hp_max: int:
	get: return character.hp_max

## 目前 HP 比例(當前/最大),ESCAPE 是否列入抽選就看這個
var hp_ratio: float:
	get:
		if hp_max <= 0:
			return 0.0
		return float(hp) / float(hp_max)

var is_disabled: bool:
	get: return character.is_disabled

var name: String:
	get: return character.name

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

## 目前是否帶有指定素質、指定方向(增益/減益)的修正,給 BattleAi 骰選權重用——
## 判斷「這次打得到的目標是不是已經生效同一個 buff/debuff 了」,不用等到重播才從
## 戰報事件反推。讀的是 _stat_modifiers(模擬當下的真實狀態),不是給 UI 用的
## _replay_stat_modifiers(見該欄位註解)。
func has_active_stat_modifier(potential_type: GameEnums.PotentialType, is_buff: bool) -> bool:
	for m in _stat_modifiers:
		if m.potential_type == potential_type and (m.multiplier > 0.0) == is_buff:
			return true
	return false

func _stat_modifier_multiplier(potential_type: GameEnums.PotentialType) -> float:
	var total := 0.0
	for m in _stat_modifiers:
		if m.potential_type == potential_type:
			total += m.multiplier
	return total

## 「顯示用」素質修正清單,跟上面 _stat_modifiers 分開維護:Battle.start() 會把整場
## 戰鬥瞬間模擬完(見 Battle 類別註解),模擬跑完那一刻 _stat_modifiers 就已經是
## 「全場結束當下」的最終結果——D. 大將之風/E. 降咒這類限時 3 回合的 buff/debuff,
## 早在模擬中途就被 tick_status_effects() 移除了,不管重播播到哪一幕點開角色面板,
## 讀到的都會是同一個定格數值,完全跟不上重播進度。這份清單改由 battle.gd 在重播
## STAT_EFFECT/STAT_EFFECT_EXPIRED 事件時同步呼叫 apply_replay_stat_effect()/
## expire_replay_stat_effect() 增減,讓 get_potential()(角色面板雷達圖專用)能顯示
## 「重播播到這一幕當下」的即時素質。開戰當下的永久被動(見 _apply_passive_skills())
## 從一開始就對兩份清單同時生效,重播不需要額外補這段。
var _replay_stat_modifiers: Array[StatModifier] = []

func apply_replay_stat_effect(potential_type: GameEnums.PotentialType, multiplier: float, rounds: int) -> void:
	for m in _replay_stat_modifiers:
		if m.potential_type == potential_type and m.multiplier == multiplier:
			m.rounds_remaining = rounds
			return
	_replay_stat_modifiers.append(StatModifier.new(potential_type, multiplier, rounds))

func expire_replay_stat_effect(potential_type: GameEnums.PotentialType, is_buff: bool) -> void:
	for m in _replay_stat_modifiers.duplicate():
		if m.potential_type == potential_type and (m.multiplier > 0.0) == is_buff:
			_replay_stat_modifiers.erase(m)

func _replay_stat_modifier_multiplier(potential_type: GameEnums.PotentialType) -> float:
	var total := 0.0
	for m in _replay_stat_modifiers:
		if m.potential_type == potential_type:
			total += m.multiplier
	return total

## 恐懼剩餘回合數(0 代表沒有恐懼)。恐懼刻意不透過 _stat_modifiers 那套素質加成/減益
## 機制實作——它不改變任何素質數值,而是直接讓 BattleAi 的行動骰選大幅偏向撤退/發呆
## (見 BattleAi._build_action_chance_map() 的 FEAR_ESCAPE_WEIGHT_MULTIPLIER/
## FEAR_DAZE_WEIGHT_MULTIPLIER),不是隨機誤擊或亂選。套用前應該先經過
## CombatResolver.judge_status_resist() 判定(意志/精神越高越容易抵抗),呼叫端抵抗成功
## 就不要呼叫 apply_fear()。
var fear_rounds_remaining: int = 0

var is_feared: bool:
	get: return fear_rounds_remaining > 0

## 重複中招只延長/刷新回合數,不會疊加出「更嚴重的恐懼」——恐懼沒有程度之分,只有
## 有沒有生效跟還剩幾回合,取較長的那個延續下去。
func apply_fear(rounds: int) -> void:
	fear_rounds_remaining = maxi(fear_rounds_remaining, rounds)

## 護盾:獨立於 HP 之外的緩衝血量,CombatResolver.apply_damage() 扣血前會先扣這個,
## 護盾值歸零才開始傷 HP。多次套用直接疊加(不像 buff/debuff 那樣「續時不疊加」)——
## 護盾本來就是消耗品,疊加是護盾的核心價值,見 SkillEffectLibrary 的護盾類技能效果。
var shield_points: float = 0.0

func add_shield(amount: float) -> void:
	shield_points += amount

## 嘲諷:命中後強制目標接下來優先攻擊自己,見 BattleAi.take_turn()/search_enemy() 的
## 呼叫端——taunted_by 不是 null 時,選定攻擊目標要優先回傳這個角色而不是最近的敵人。
var taunted_by: BattleCharacter = null
var taunt_rounds_remaining: int = 0

func apply_taunt(source: BattleCharacter, rounds: int) -> void:
	taunted_by = source
	taunt_rounds_remaining = maxi(taunt_rounds_remaining, rounds)

## 封印:接下來幾回合無法選用主動技能,只能普通攻擊/發呆/撤退,見
## BattleAi._build_action_chance_map() 讀這個欄位排除所有技能候選。
var seal_rounds_remaining: int = 0

var is_sealed: bool:
	get: return seal_rounds_remaining > 0

func apply_seal(rounds: int) -> void:
	seal_rounds_remaining = maxi(seal_rounds_remaining, rounds)

## 降治療:接下來幾回合受到的治療效果打折扣,見 CombatResolver.apply_heal() 的呼叫端
## (HEAL_DOWN_MULTIPLIER)。
var heal_down_rounds_remaining: int = 0

var is_healing_reduced: bool:
	get: return heal_down_rounds_remaining > 0

func apply_heal_down(rounds: int) -> void:
	heal_down_rounds_remaining = maxi(heal_down_rounds_remaining, rounds)

## 全隊限時破防/必定暴擊增益(破陣先鋒/常勝威名):見 GameEnums.SkillMechanic.
## GRANT_ARMOR_PIERCE/GRANT_GUARANTEED_CRIT 註解,SkillEffectLibrary.
## check_chance_armor_pierce()/check_chance_guaranteed_crit() 一併檢查這兩個欄位。
var armor_pierce_rounds: int = 0
var is_armor_piercing: bool:
	get: return armor_pierce_rounds > 0

func apply_armor_pierce_buff(rounds: int) -> void:
	armor_pierce_rounds = maxi(armor_pierce_rounds, rounds)

var guaranteed_crit_rounds: int = 0
var is_guaranteed_crit: bool:
	get: return guaranteed_crit_rounds > 0

func apply_guaranteed_crit_buff(rounds: int) -> void:
	guaranteed_crit_rounds = maxi(guaranteed_crit_rounds, rounds)

## 異常抵抗加成(泰然自若):疊加進 CombatResolver.judge_status_resist() 的抵抗率,
## 見 Skill.mechanics 對應說明。永久生效,不走 _stat_modifiers 那套回合數機制。
var bonus_status_resist_percent: float = 0.0

## 技能權重暫時加成(乘勝追擊/智將韜略):BattleAi._build_action_chance_map() 對所有
## 主動技能(不含普攻/發呆/撤退)候選乘上這個倍數,見 GameEnums.SkillMechanic.
## KILL_MOMENTUM 註解。倒數歸零時倍數自動失效(見 skill_weight_boost_multiplier getter)。
var skill_weight_boost_rounds: int = 0
var _skill_weight_boost_value: float = 1.0

var skill_weight_boost_multiplier: float:
	get: return _skill_weight_boost_value if skill_weight_boost_rounds > 0 else 1.0

func apply_skill_weight_boost(bonus_ratio: float, rounds: int) -> void:
	_skill_weight_boost_value = 1.0 + bonus_ratio
	skill_weight_boost_rounds = maxi(skill_weight_boost_rounds, rounds)

## 限定一次的強力反擊(怒濤反擊):整場戰鬥只會觸發一次,觸發後標記為已使用。
var has_used_limited_execute_counter: bool = false

## 異常解除:清除身上一項異常狀態,瞬間生效不算持續效果,優先順序上——封印/恐懼/嘲諷這類
## 「完全限制行動」的先清,降治療其次,最後才清一般的素質減益(挑第一個找到的減益修正)。
## 沒有任何異常狀態時什麼都不做。清除的每一種狀態都直接記一筆對應的戰報事件
## (StatusMechanicEvent/StatEffectExpiredEvent,is_active/到期=false),讓
## BattlePartyRoster/BattleUnitVisual 的狀態文字跟著同步拿掉,不會殘留一個其實已經被
## 淨化掉、但畫面還顯示著的過期狀態。
func cleanse_one_status() -> void:
	if is_sealed:
		seal_rounds_remaining = 0
		battle.log_event(StatusMechanicEvent.new(self, GameEnums.SkillMechanic.SEAL, false))
		return
	if is_feared:
		fear_rounds_remaining = 0
		battle.log_event(StatusMechanicEvent.new(self, GameEnums.SkillMechanic.FEAR, false))
		return
	if taunt_rounds_remaining > 0:
		taunt_rounds_remaining = 0
		taunted_by = null
		battle.log_event(StatusMechanicEvent.new(self, GameEnums.SkillMechanic.TAUNT, false))
		return
	if is_healing_reduced:
		heal_down_rounds_remaining = 0
		battle.log_event(StatusMechanicEvent.new(self, GameEnums.SkillMechanic.HEAL_DOWN, false))
		return
	for m in _stat_modifiers:
		if m.multiplier < 0.0 and m.rounds_remaining >= 0:
			m.rounds_remaining = 0
			_stat_modifiers.erase(m)
			battle.log_event(StatEffectExpiredEvent.new(self, [m.potential_type], false))
			return

## 每回合結束時由 Battle._round_end() 呼叫:有時限的修正倒數 1 回合,歸零就移除;
## 永久修正(rounds_remaining < 0)不受影響。恐懼/嘲諷/封印/降治療/全隊限時破防&必定
## 暴擊也在這裡一併倒數(不是 StatModifier,倒數歸零時記進 TickStatusResult.
## expired_mechanics,不是 expired_stat_modifiers);嘲諷倒數歸零時一併清掉
## taunted_by,避免殘留一個過期的強制目標。skill_weight_boost_rounds(乘勝追擊/智將韜略)
## 沒有對應的戰報 UI 顯示需求,倒數不記錄到期。
func tick_status_effects() -> TickStatusResult:
	var expired_mechanics: Array[GameEnums.SkillMechanic] = []

	if fear_rounds_remaining > 0:
		fear_rounds_remaining -= 1
		if fear_rounds_remaining <= 0:
			expired_mechanics.append(GameEnums.SkillMechanic.FEAR)
	if seal_rounds_remaining > 0:
		seal_rounds_remaining -= 1
		if seal_rounds_remaining <= 0:
			expired_mechanics.append(GameEnums.SkillMechanic.SEAL)
	if heal_down_rounds_remaining > 0:
		heal_down_rounds_remaining -= 1
		if heal_down_rounds_remaining <= 0:
			expired_mechanics.append(GameEnums.SkillMechanic.HEAL_DOWN)
	if taunt_rounds_remaining > 0:
		taunt_rounds_remaining -= 1
		if taunt_rounds_remaining <= 0:
			taunted_by = null
			expired_mechanics.append(GameEnums.SkillMechanic.TAUNT)
	if skill_weight_boost_rounds > 0:
		skill_weight_boost_rounds -= 1
	if armor_pierce_rounds > 0:
		armor_pierce_rounds -= 1
		if armor_pierce_rounds <= 0:
			expired_mechanics.append(GameEnums.SkillMechanic.GRANT_ARMOR_PIERCE)
	if guaranteed_crit_rounds > 0:
		guaranteed_crit_rounds -= 1
		if guaranteed_crit_rounds <= 0:
			expired_mechanics.append(GameEnums.SkillMechanic.GRANT_GUARANTEED_CRIT)

	var expired_stats: Array[StatModifier] = []
	for m in _stat_modifiers.duplicate():
		if m.rounds_remaining < 0:
			continue
		m.rounds_remaining -= 1
		if m.rounds_remaining <= 0:
			_stat_modifiers.erase(m)
			expired_stats.append(m)
	return TickStatusResult.new(expired_stats, expired_mechanics)

var strength: float:
	get: return character.strength * (1.0 + _stat_modifier_multiplier(GameEnums.PotentialType.STRENGTH))
var agility: float:
	get: return character.agility * (1.0 + _stat_modifier_multiplier(GameEnums.PotentialType.AGILITY))
var dexterity: float:
	get: return character.dexterity * (1.0 + _stat_modifier_multiplier(GameEnums.PotentialType.DEXTERITY))
var vitality: float:
	get: return character.vitality * (1.0 + _stat_modifier_multiplier(GameEnums.PotentialType.VITALITY))
var intelligence: float:
	get: return character.intelligence * (1.0 + _stat_modifier_multiplier(GameEnums.PotentialType.INTELLIGENCE))
var mentality: float:
	get: return character.mentality * (1.0 + _stat_modifier_multiplier(GameEnums.PotentialType.MENTALITY))

## 跟 Character.get_potential() 對應,但回傳的是套用完戰場加成(裝備/等級皆含 Character 本身
## 已算好的部分,再疊加 _replay_stat_modifiers 的被動/主動技能、buff/debuff)之後的
## 「即時」數值——這裡刻意讀 _replay_stat_modifiers 而不是上面 strength/agility 等
## 屬性讀的 _stat_modifiers,因為後者是整場模擬結束後的最終結果,前者才會隨重播進度
## 增減(見 _replay_stat_modifiers 註解)。UI(角色面板雷達圖)想顯示戰場當下的真實
## 素質時用這個,不要直接讀 Character.get_potential()。
func get_potential(potential_type: int) -> float:
	var base: float = character.get_potential(potential_type)
	return base * (1.0 + _replay_stat_modifier_multiplier(potential_type))

## 行動速度(回合排序用),暫以敏捷做為速度來源
var action_speed: float:
	get: return agility
