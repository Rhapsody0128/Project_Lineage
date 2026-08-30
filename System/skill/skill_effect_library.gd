class_name SkillEffectLibrary
extends RefCounted

## 技能「效果」庫:專門存放技能的數值計算與戰鬥表現(log_event/造成傷害等),
## SkillLibrary 只負責組裝技能資料(名稱/rank/範圍/綁定武器…),實際效果一律
## 透過 Callable(SkillEffectLibrary, "xxx") 帶入 Skill.action。
##
## 傷害/閃避/暴擊/守護/異常抵抗判定一律呼叫 CombatResolver,不直接呼叫 BattleCharacter 的
## 實例方法——BattleCharacter 的一般攻擊(attack())也是呼叫同一份 CombatResolver,兩邊共用
## 同一套底層,不再互相呼叫對方。
##
## 這裡的函式刻意設計成「一個效果配方對應一個通用函式」,不是「一個技能對應一個函式」——
## 120 條技能之間差異靠 Skill 自己的資料欄位(effect_stat/secondary_stat/mechanics/
## buffed_potential_types/duration_rounds…)表達,武器/素質/機制這些會變動的參數透過
## Callable.bind() 綁進 action,而不是各寫一個同名但內容微調的效果函式。AI 端也是同一套
## 精神:BattleAi 只看 Skill 的資料欄位,不看技能叫什麼名字。

## 素質對素質的傷害公式:先用「攻擊素質 vs 防禦素質(皆 0~200 範圍)」本身的比例
## 算出封頂上限(damage_ratio,基本攻擊 multiplier=1 時等同這條比例本身),
## 技能倍率(multiplier)只放大最終傷害輸出,不參與「防禦擋不擋得住」的判定——
## 否則像火球術 multiplier=2 這種技能,會變成要防禦贏過「攻擊*2」才不封頂,
## 使封頂(每個目標傷害都一樣)的情況異常頻繁,失去範圍技能命中多人時
## 應該因為各自防禦不同而分出高低傷害的意義。
static func _skill_damage(attack_value: float, defense_value: float, multiplier: float) -> float:
	var damage_ratio: float = min(attack_value / defense_value, 1.0)
	var damage: float = attack_value * multiplier * damage_ratio
	return damage

## 依武器決定攻擊方要用哪個(或哪幾個)素質當輸出:法杖=智慧、弓=靈巧、劍=力量、
## 盾=力量*0.4+體質*0.6、匕首=力量*0.4+敏捷*0.6、捕夢網=智慧*0.4+信仰*0.6,
static func _attack_value(self_character: BattleCharacter, weapon: GameEnums.WeaponType) -> float:
	match weapon:
		GameEnums.WeaponType.SWORD:
			return self_character.strength
		GameEnums.WeaponType.STAFF:
			return self_character.intelligence
		GameEnums.WeaponType.BOW:
			return self_character.dexterity
		GameEnums.WeaponType.SHIELD:
			return self_character.strength * 0.4 + self_character.vitality * 0.6
		GameEnums.WeaponType.DAGGER:
			return self_character.strength * 0.4 + self_character.agility * 0.6
		GameEnums.WeaponType.DREAMCATCHER:
			return self_character.intelligence * 0.4 + self_character.mentality * 0.6
		_:
			return 0

## 依武器決定防禦方要用哪個素質:法杖/捕夢網打的是信仰,其餘一律是體質。
static func _defense_value(enemy_character: BattleCharacter, weapon: GameEnums.WeaponType) -> float:
	match weapon:
		GameEnums.WeaponType.STAFF, GameEnums.WeaponType.DREAMCATCHER:
			return enemy_character.mentality
		_:
			return enemy_character.vitality

## 基本攻擊(BattleCharacter.attack() 專用):套用跟技能一樣的武器素質配對,倍率固定 1。
## armor_pierce(破綻洞察機率觸發)時防禦值直接視為攻擊值,等同無視防禦。
static func basic_attack_damage(self_character: BattleCharacter, enemy_character: BattleCharacter, weapon: GameEnums.WeaponType, armor_pierce: bool = false) -> float:
	var attack_value := _attack_value(self_character, weapon)
	var defense_value := attack_value if armor_pierce else _defense_value(enemy_character, weapon)
	return _skill_damage(attack_value, defense_value, 1.0)

## 六個具名素質的小型對照表,雙屬性乘區公式共用,不用另外為每個素質寫一個 getter 呼叫。
static func _potential_value(bc: BattleCharacter, potential_type: int) -> float:
	match potential_type:
		GameEnums.PotentialType.STRENGTH:
			return bc.strength
		GameEnums.PotentialType.VITALITY:
			return bc.vitality
		GameEnums.PotentialType.AGILITY:
			return bc.agility
		GameEnums.PotentialType.DEXTERITY:
			return bc.dexterity
		GameEnums.PotentialType.INTELLIGENCE:
			return bc.intelligence
		GameEnums.PotentialType.MENTALITY:
			return bc.mentality
		_:
			return 0.0

static func _is_magic_stat(potential_type: int) -> bool:
	return potential_type == GameEnums.PotentialType.INTELLIGENCE or potential_type == GameEnums.PotentialType.MENTALITY

## 不綁定單一武器的技能(血統覺醒技/大將技/部分血統雙修技)專用的攻擊值:
## effect_stat×skill_ratio,再加上 secondary_stat×secondary_ratio(沒有第二屬性時
## secondary_stat 是 -1,_potential_value() 回傳 0,等同單屬性)。跟 _attack_value()
## 的差異是這裡的係數已經包含在算式裡,不再另外乘 skill_ratio,呼叫端統一用
## multiplier=1.0 餵給 _skill_damage()。
static func _generic_attack_value(self_character: BattleCharacter, skill: Skill) -> float:
	var value := _potential_value(self_character, skill.effect_stat) * skill.skill_ratio
	if skill.secondary_stat != -1:
		value += _potential_value(self_character, skill.secondary_stat) * skill.secondary_ratio
	return value

## 防禦方素質:只要主/副屬性任一是智慧或信仰,就視為魔法系,吃防禦方信仰,其餘吃體質——
## 跟武器版 _defense_value() 同樣的判斷,只是依技能自己宣告的屬性組合決定,不查武器表。
static func _generic_defense_value(enemy_character: BattleCharacter, skill: Skill) -> float:
	var is_magic := _is_magic_stat(skill.effect_stat) or (skill.secondary_stat != -1 and _is_magic_stat(skill.secondary_stat))
	return enemy_character.mentality if is_magic else enemy_character.vitality

## 攻擊類技能共用的核心流程:記一筆 skill 事件(以 primary_target 決定動畫朝向與戰報文字,
## detail 帶施法前的選技能/選目標判定明細),再對 skill.resolve_targets() 算出的每個
## 目標各自判定閃避、各自判定暴擊、各自造成傷害——範圍內每個目標都是獨立個體。
## attack_value 是固定值(這次施法當下算好一次),defense_value_fn 是
## Callable(enemy_character)->float,因為防禦值因人而異、要對每個目標分別計算。
##
## 單體技能(resolve_targets() 只算出 1 個目標)在這裡先過一次 CombatResolver.resolve_guard()
## ——如果附近有守護技能的友軍頂替,實際受擊的目標會換成守護者(連 skill 事件顯示的
## target 也一併換掉,動畫才會對準真正挨打的人),範圍技能(命中多人)則不觸發守護,
## 因為守護只擋得住「單體」攻擊(見 B. 守護的設計)。
## damage_multiplier 由呼叫端決定要不要再乘 skill.skill_ratio——武器綁定攻擊
## (weapon_attack())傳入的 attack_value 是純素質,係數在這裡乘(damage_multiplier=
## skill.skill_ratio);不綁定武器的雙屬性攻擊(generic_attack())已經把
## skill_ratio/secondary_ratio 都算進 attack_value 裡,這裡改傳 1.0,避免係數被乘兩次。
static func _cast_attack_skill_core(self_character: BattleCharacter, primary_target: BattleCharacter, skill: Skill, attack_value: float, damage_multiplier: float, defense_value_fn: Callable, cast_detail: String = "") -> void:
	var targets := skill.resolve_targets(self_character, primary_target)
	var display_target := primary_target
	var guarded := false
	var guard_damage_multiplier := 1.0

	if targets.size() == 1:
		var guard_result := CombatResolver.resolve_guard(targets[0], self_character)
		guarded = guard_result.target != targets[0]
		targets = [guard_result.target]
		display_target = guard_result.target
		guard_damage_multiplier = guard_result.damage_multiplier

	self_character.battle.log_event(SkillEvent.new(self_character, display_target, skill.name, cast_detail))

	for enemy_character in targets:
		var defense_value: float = defense_value_fn.call(enemy_character)
		for _i in range(skill.multi_strike_count):
			_resolve_attack_hit(self_character, enemy_character, skill, attack_value, damage_multiplier, defense_value, guarded, guard_damage_multiplier)

## 單次攻擊判定:必中(skill.true_hit)略過閃避判定;守護頂替也視為必中(用身體擋下來,
## 不會再靈巧閃開,跟既有行為一致);完美迴避(對方持有 PERFECT_DODGE 武器被動)是獨立
## 於一般閃避判定之外的第二層判定,骰中就直接視為沒命中;破防(ARMOR_PIERCE)讓
## _skill_damage() 的 damage_ratio 視為 1.0(把 attack_value 當防禦值代入,等同無視
## 防禦);必定暴擊(GUARANTEED_CRIT)略過暴擊判定直接視為暴擊。命中後才檢查反擊/
## 反應治療——沒命中(被閃開/被完美迴避)不會觸發任何一方的反應機制。
static func _resolve_attack_hit(self_character: BattleCharacter, enemy_character: BattleCharacter, skill: Skill, attack_value: float, damage_multiplier: float, defense_value: float, guarded: bool, guard_damage_multiplier: float) -> void:
	var dodge_check: DodgeResult
	if guarded:
		dodge_check = DodgeResult.new(false, "%s 挺身守護,直接承受這次攻擊,不判定閃避" % enemy_character.name)
	elif skill.true_hit:
		dodge_check = DodgeResult.new(false, "%s 的技能必中,無視迴避判定" % self_character.name)
	else:
		var perfect_dodge_skill := enemy_character.character.find_skill_with_mechanic(GameEnums.SkillMechanic.PERFECT_DODGE)
		if perfect_dodge_skill != null:
			var perfect_check := CombatResolver.judge_reactive_trigger(enemy_character.name, perfect_dodge_skill.base_chance)
			var perfect_detail := "完美迴避判定:\n%s" % perfect_check.detail
			dodge_check = DodgeResult.new(perfect_check.triggered, perfect_detail)
			if perfect_check.triggered:
				enemy_character.battle.log_event(DodgeEvent.new(self_character, enemy_character, perfect_detail, perfect_dodge_skill.name))
		else:
			dodge_check = DodgeResult.new(false, "")
		if not dodge_check.dodged:
			dodge_check = CombatResolver.judge_dodge(self_character, enemy_character)

	if dodge_check.dodged:
		maybe_dodge_counter(enemy_character, self_character)
		return

	var proc_skill_names: Array[String] = []
	var armor_pierce := skill.mechanics.has(GameEnums.SkillMechanic.ARMOR_PIERCE) or check_chance_armor_pierce(self_character)
	var effective_defense := attack_value if armor_pierce else defense_value
	var damage := _skill_damage(attack_value, effective_defense, damage_multiplier)

	var crit_check: CritResult
	if skill.mechanics.has(GameEnums.SkillMechanic.GUARANTEED_CRIT):
		crit_check = CritResult.new(true, "%s 的技能必定暴擊" % skill.name)
	elif self_character.is_guaranteed_crit:
		crit_check = CritResult.new(true, "%s 的被動使這次攻擊必定暴擊" % self_character.name)
	elif check_chance_guaranteed_crit(self_character):
		var crit_skill := self_character.character.find_skill_with_mechanic(GameEnums.SkillMechanic.CHANCE_GUARANTEED_CRIT)
		crit_check = CritResult.new(true, "%s 發動被動技能「%s」,這次攻擊必定暴擊" % [self_character.name, crit_skill.name])
		proc_skill_names.append(crit_skill.name)
	else:
		crit_check = CombatResolver.judge_crit(self_character, enemy_character)
	if crit_check.critical:
		damage *= CombatResolver.crit_damage_multiplier()

	var armor_pierce_detail := ""
	if armor_pierce and not skill.mechanics.has(GameEnums.SkillMechanic.ARMOR_PIERCE) and not self_character.is_armor_piercing:
		var armor_pierce_skill := self_character.character.find_skill_with_mechanic(GameEnums.SkillMechanic.CHANCE_ARMOR_PIERCE)
		armor_pierce_detail = "\n\n%s 發動被動技能「%s」,這次攻擊無視防禦" % [self_character.name, armor_pierce_skill.name]
		proc_skill_names.append(armor_pierce_skill.name)

	var damage_detail := "%s\n\n%s%s" % [dodge_check.detail, crit_check.detail, armor_pierce_detail]
	if guarded:
		damage *= guard_damage_multiplier
		damage_detail += "\n\n此傷害因守護減少 30%"
	CombatResolver.apply_damage(enemy_character, damage, crit_check.critical, damage_detail, self_character, proc_skill_names)

	maybe_counter_attack(self_character, enemy_character)
	maybe_reactive_heal(enemy_character)
	maybe_kill_momentum(self_character, enemy_character)
	maybe_limited_execute_counter(enemy_character, self_character)

## 反擊:命中後,受擊者(enemy_character,這裡是「被攻擊到的那一方」)如果持有掛
## COUNTER 機制的武器被動,依該技能的 base_chance(武器被動不吃行動骰選,這個欄位當純
## 觸發機率用)骰一次,觸發就對原攻擊者(original_attacker)造成一次普通攻擊等值的反擊
## 傷害——反擊本身不再判定閃避/暴擊,單純用普通攻擊公式算傷害,避免無限連鎖(反擊觸發
## 反擊)。defender 若剛好被這次攻擊打死(is_disabled),直接不觸發——人都死了不會反擊。
static func maybe_counter_attack(original_attacker: BattleCharacter, defender: BattleCharacter) -> void:
	if defender.is_disabled:
		return
	var counter_skill := defender.character.find_skill_with_mechanic(GameEnums.SkillMechanic.COUNTER)
	if counter_skill == null:
		return
	var trigger := CombatResolver.judge_reactive_trigger(defender.name, counter_skill.base_chance)
	if not trigger.triggered:
		return
	var counter_damage := basic_attack_damage(defender, original_attacker, defender.character.weapon)
	defender.battle.log_event(SkillEvent.new(defender, original_attacker, counter_skill.name, trigger.detail))
	CombatResolver.apply_damage(original_attacker, counter_damage, false, trigger.detail)

## 反應治療:受擊者(target)身邊(以 target 自身為中心找,範圍固定 2 格,對應設計上的
## 「以自身為中心 2 格內」)如果有友軍持有掛 REACTIVE_HEAL 機制的武器被動,依該技能的
## base_chance 骰一次,觸發就對受擊的 target 施放一次小量治療(治療量吃該持有者的
## effect_stat/skill_ratio,沿用一般攻擊/技能同一套素質公式)。target 若剛好被這次攻擊
## 打死(is_disabled),直接不觸發——已陣亡不該被救回來。
const REACTIVE_HEAL_RANGE := 2

static func maybe_reactive_heal(target: BattleCharacter) -> void:
	if target.is_disabled:
		return
	for ally in target.allies:
		var heal_skill := ally.character.find_skill_with_mechanic(GameEnums.SkillMechanic.REACTIVE_HEAL)
		if heal_skill == null:
			continue
		if Util.manhattan_distance(ally.grid_pos, target.grid_pos) > REACTIVE_HEAL_RANGE:
			continue
		var trigger := CombatResolver.judge_reactive_trigger(ally.name, heal_skill.base_chance)
		if not trigger.triggered:
			continue
		var heal_value := _potential_value(ally, heal_skill.effect_stat) * heal_skill.skill_ratio
		ally.battle.log_event(SkillEvent.new(ally, target, heal_skill.name, trigger.detail))
		CombatResolver.apply_heal(target, heal_value, trigger.detail)
		return # 一次受擊只觸發一位友軍的反應治療,避免多個持有者同時洗版式觸發。

## 閃避後反擊(戰鬥直覺):防禦方成功閃避後,依自己持有的 DODGE_COUNTER 武器被動/通用
## 被動的 base_chance 機率立即反擊剛才的攻擊者,反擊本身不判定閃避/暴擊(跟 maybe_counter_attack
## 同樣的理由:避免無限連鎖)。
static func maybe_dodge_counter(dodger: BattleCharacter, original_attacker: BattleCharacter) -> void:
	var skill := dodger.character.find_skill_with_mechanic(GameEnums.SkillMechanic.DODGE_COUNTER)
	if skill == null:
		return
	var trigger := CombatResolver.judge_reactive_trigger(dodger.name, skill.base_chance)
	if not trigger.triggered:
		return
	var counter_damage := basic_attack_damage(dodger, original_attacker, dodger.character.weapon)
	dodger.battle.log_event(SkillEvent.new(dodger, original_attacker, skill.name, trigger.detail))
	CombatResolver.apply_damage(original_attacker, counter_damage, false, trigger.detail)

## 攻擊方普攻/技能機率觸發破防/必定暴擊(破綻洞察/絕殺直覺):base_chance 當純觸發機率用,
## 跟武器被動的反應式機制同一套判定,呼叫端(_resolve_attack_hit()/
## BattleCharacter._resolve_basic_attack_hit())自己決定怎麼利用這個結果。
## 破陣先鋒/常勝威名的全隊限時增益(attacker.is_armor_piercing/is_guaranteed_crit)一律
## 生效,跟破綻洞察/絕殺直覺的機率觸發是兩條獨立的路徑,任一成立就算數。
static func check_chance_armor_pierce(attacker: BattleCharacter) -> bool:
	if attacker.is_armor_piercing:
		return true
	var skill := attacker.character.find_skill_with_mechanic(GameEnums.SkillMechanic.CHANCE_ARMOR_PIERCE)
	if skill == null:
		return false
	return CombatResolver.judge_reactive_trigger(attacker.name, skill.base_chance).triggered

static func check_chance_guaranteed_crit(attacker: BattleCharacter) -> bool:
	if attacker.is_guaranteed_crit:
		return true
	var skill := attacker.character.find_skill_with_mechanic(GameEnums.SkillMechanic.CHANCE_GUARANTEED_CRIT)
	if skill == null:
		return false
	return CombatResolver.judge_reactive_trigger(attacker.name, skill.base_chance).triggered

## 擊殺後技能權重暫時提升(乘勝追擊):命中造成的傷害若讓 defender 陣亡,攻擊方持有
## KILL_MOMENTUM 被動時取得暫時的技能權重加成(skill.skill_ratio 是加成比例,
## duration_rounds 是持續回合數),見 BattleCharacter.apply_skill_weight_boost()/
## BattleAi._build_action_chance_map()。
static func maybe_kill_momentum(attacker: BattleCharacter, defender: BattleCharacter) -> void:
	if not defender.is_disabled:
		return
	var skill := attacker.character.find_skill_with_mechanic(GameEnums.SkillMechanic.KILL_MOMENTUM)
	if skill == null:
		return
	attacker.apply_skill_weight_boost(skill.skill_ratio, skill.duration_rounds)

## 限一次的強力反擊(怒濤反擊):defender 受擊後若還存活、HP 低於 secondary_ratio 門檻、
## 且整場戰鬥還沒觸發過,立即對 attacker 造成一次強力反擊(用 skill 自己宣告的
## effect_stat/skill_ratio 當攻擊值,不透過武器素質配對,呼應「不綁定武器的血統/通用技」
## 慣例)。
static func maybe_limited_execute_counter(defender: BattleCharacter, attacker: BattleCharacter) -> void:
	if defender.is_disabled or defender.has_used_limited_execute_counter:
		return
	var skill := defender.character.find_skill_with_mechanic(GameEnums.SkillMechanic.LIMITED_EXECUTE_COUNTER)
	if skill == null or defender.hp_ratio >= skill.secondary_ratio:
		return
	defender.has_used_limited_execute_counter = true
	var counter_damage := _generic_attack_value(defender, skill)
	var counter_detail := "%s 觸發限定一次的強力反擊(HP < %.0f%%)" % [defender.name, skill.secondary_ratio * 100.0]
	defender.battle.log_event(SkillEvent.new(defender, attacker, skill.name, counter_detail))
	CombatResolver.apply_damage(attacker, counter_damage, false, counter_detail)

## 異常狀態套用共用邏輯:FEAR/SEAL/TAUNT/HEAL_DOWN 這類「施加在敵人身上、對方會抗拒」
## 的負面機制,套用前先過 CombatResolver.judge_status_resist() 抵抗判定(意志/精神越高
## 越容易抵抗);CLEANSE(異常解除)是幫友軍清除異常,不需要抵抗判定,直接套用。
## skill.mechanics 為空(純攻擊/純屬性技能)時什麼都不做。
const _NEGATIVE_MECHANICS := [
	GameEnums.SkillMechanic.FEAR, GameEnums.SkillMechanic.SEAL,
	GameEnums.SkillMechanic.TAUNT, GameEnums.SkillMechanic.HEAL_DOWN,
]

static func _has_negative_mechanic(skill: Skill) -> bool:
	for m in skill.mechanics:
		if m in _NEGATIVE_MECHANICS:
			return true
	return false

static func _apply_status_mechanics(self_character: BattleCharacter, targets: Array[BattleCharacter], skill: Skill) -> void:
	if skill.mechanics.is_empty():
		return

	var is_negative := _has_negative_mechanic(skill)
	for target in targets:
		var resisted := false
		var status_detail := ""
		if is_negative:
			var resist := CombatResolver.judge_status_resist(target)
			resisted = resist.resisted
			status_detail = resist.detail

		if not resisted:
			for mechanic in skill.mechanics:
				match mechanic:
					GameEnums.SkillMechanic.FEAR:
						target.apply_fear(skill.duration_rounds)
						target.battle.log_event(StatusMechanicEvent.new(target, mechanic, true))
					GameEnums.SkillMechanic.SEAL:
						target.apply_seal(skill.duration_rounds)
						target.battle.log_event(StatusMechanicEvent.new(target, mechanic, true))
					GameEnums.SkillMechanic.TAUNT:
						target.apply_taunt(self_character, skill.duration_rounds)
						target.battle.log_event(StatusMechanicEvent.new(target, mechanic, true))
					GameEnums.SkillMechanic.HEAL_DOWN:
						target.apply_heal_down(skill.duration_rounds)
						target.battle.log_event(StatusMechanicEvent.new(target, mechanic, true))
					GameEnums.SkillMechanic.CLEANSE:
						target.cleanse_one_status()
					GameEnums.SkillMechanic.GRANT_ARMOR_PIERCE:
						target.apply_armor_pierce_buff(skill.duration_rounds)
						target.battle.log_event(StatusMechanicEvent.new(target, mechanic, true))
					GameEnums.SkillMechanic.GRANT_GUARANTEED_CRIT:
						target.apply_guaranteed_crit_buff(skill.duration_rounds)
						target.battle.log_event(StatusMechanicEvent.new(target, mechanic, true))

		target.battle.log_event(SkillEvent.new(self_character, target, skill.name, status_detail))

## D/E 共用:對多個目標套用同一組素質修正,每個目標各自記一筆 stat_effect 事件
## (給戰報 UI/頭像箭頭用),multiplier 正值是增益、負值是減益。
static func _apply_stat_effect(targets: Array[BattleCharacter], potential_types: Array[int], multiplier: float, rounds: int) -> void:
	for target in targets:
		for potential_type in potential_types:
			target.add_stat_modifier(potential_type, multiplier, rounds)
		target.battle.log_event(StatEffectEvent.new(target, potential_types, multiplier, rounds))


# =========================================================
# 武器綁定攻擊(六種武器共用同一套素質配對,見 _attack_value()/_defense_value())
# =========================================================

## 純攻擊(武器綁定):不帶任何 mechanics 之外的複合效果,attack_value 是純素質、
## skill.skill_ratio 在 _resolve_attack_hit() 裡才乘上去。
static func weapon_attack(self_character: BattleCharacter, target: BattleCharacter, skill: Skill, cast_detail: String, weapon: GameEnums.WeaponType) -> void:
	_cast_attack_skill_core(self_character, target, skill, _attack_value(self_character, weapon), skill.skill_ratio, func(ec): return _defense_value(ec, weapon), cast_detail)

## 攻擊(武器綁定)+ 額外的素質減益(例如絕影突刺削弱敏捷、寒冰箭拖慢腳步):傷害結算
## 用 weapon_attack() 同一套,結束後再對命中範圍內的目標套用一次 debuff_stats/
## debuff_ratio(獨立於閃避判定之外,詛咒類效果慣例上無視命中與否,見既有 curse_debuff()
## 的設計)。
static func weapon_attack_with_stat_debuff(self_character: BattleCharacter, target: BattleCharacter, skill: Skill, cast_detail: String, weapon: GameEnums.WeaponType, debuff_stats: Array[int], debuff_ratio: float) -> void:
	weapon_attack(self_character, target, skill, cast_detail, weapon)
	_apply_stat_effect(skill.resolve_targets(self_character, target), debuff_stats, debuff_ratio, skill.duration_rounds)

## 攻擊(武器綁定)+ 機制型異常狀態(恐懼/封印/降治療等,見 skill.mechanics):傷害結算
## 完再對同一批目標套用異常狀態,每個目標各自判定抵抗。
static func weapon_attack_with_mechanic(self_character: BattleCharacter, target: BattleCharacter, skill: Skill, cast_detail: String, weapon: GameEnums.WeaponType) -> void:
	weapon_attack(self_character, target, skill, cast_detail, weapon)
	_apply_status_mechanics(self_character, skill.resolve_targets(self_character, target), skill)


# =========================================================
# 不綁定單一武器的攻擊(血統覺醒技/雙修技,見 _generic_attack_value())
# =========================================================

static func generic_attack(self_character: BattleCharacter, target: BattleCharacter, skill: Skill, cast_detail: String = "") -> void:
	_cast_attack_skill_core(self_character, target, skill, _generic_attack_value(self_character, skill), 1.0, func(ec): return _generic_defense_value(ec, skill), cast_detail)

static func generic_attack_with_stat_debuff(self_character: BattleCharacter, target: BattleCharacter, skill: Skill, cast_detail: String, debuff_stats: Array[int], debuff_ratio: float) -> void:
	generic_attack(self_character, target, skill, cast_detail)
	_apply_stat_effect(skill.resolve_targets(self_character, target), debuff_stats, debuff_ratio, skill.duration_rounds)

static func generic_attack_with_mechanic(self_character: BattleCharacter, target: BattleCharacter, skill: Skill, cast_detail: String = "") -> void:
	generic_attack(self_character, target, skill, cast_detail)
	_apply_status_mechanics(self_character, skill.resolve_targets(self_character, target), skill)


# =========================================================
# 治療 / 護盾(HEAL / SHIELD 類型,自身為施法中心,不需要鎖定敵人)
# =========================================================

## 治療:heal_value 沿用 _generic_attack_value() 的雙屬性公式(單屬性技能只是
## secondary_stat=-1 的特例,跟舊版 dreamcatcher_heal() 的 MEN×ratio 行為一致)。
## resolve_targets(self, self) 是自我中心施放的既有慣例(RADIUS/ALL_ALLIES 都適用)。
static func heal(self_character: BattleCharacter, primary_target: BattleCharacter, skill: Skill, cast_detail: String = "") -> void:
	self_character.battle.log_event(SkillEvent.new(self_character, self_character, skill.name, cast_detail))

	var heal_value := _generic_attack_value(self_character, skill)
	var heal_detail := "%s 治療量 = %.1f" % [self_character.name, heal_value]
	for ally in skill.resolve_targets(self_character, self_character):
		CombatResolver.apply_heal(ally, heal_value, heal_detail)

## 治療 + 異常解除(淨化之光/夢境輪迴/鹿靈庇世):治療完再對同一批目標清一項異常狀態,
## 不需要抵抗判定(異常解除是幫己方清狀態,不是施加在敵人身上)。
static func heal_with_cleanse(self_character: BattleCharacter, primary_target: BattleCharacter, skill: Skill, cast_detail: String = "") -> void:
	heal(self_character, primary_target, skill, cast_detail)
	for ally in skill.resolve_targets(self_character, self_character):
		ally.cleanse_one_status()

## 護盾:shield_value 一樣沿用 _generic_attack_value(),賦予每個目標一層獨立於 HP 之外
## 的緩衝血量(BattleCharacter.add_shield()),不直接回 HP,見 ShieldEvent。
static func shield(self_character: BattleCharacter, primary_target: BattleCharacter, skill: Skill, cast_detail: String = "") -> void:
	self_character.battle.log_event(SkillEvent.new(self_character, self_character, skill.name, cast_detail))

	var shield_value := _generic_attack_value(self_character, skill)
	var shield_detail := "%s 護盾量 = %.1f,持續 %d 回合" % [self_character.name, shield_value, skill.duration_rounds]
	for ally in skill.resolve_targets(self_character, self_character):
		ally.add_shield(shield_value)
		ally.battle.log_event(ShieldEvent.new(ally, roundi(shield_value), roundi(ally.shield_points), shield_detail))

## 治療 + 護盾(安寢術):同一次施放同時給治療量與護盾量,兩者各自沿用自己的事件類別。
static func heal_with_shield(self_character: BattleCharacter, primary_target: BattleCharacter, skill: Skill, cast_detail: String = "") -> void:
	heal(self_character, primary_target, skill, cast_detail)
	shield(self_character, primary_target, skill, cast_detail)

## 治療 + 素質增益(鐵血統帥):同一次施放同時治療全隊、提升 skill.buffed_potential_types
## 宣告的素質,兩者共用同一批目標(skill.resolve_targets(self, self))。
static func heal_with_buff(self_character: BattleCharacter, primary_target: BattleCharacter, skill: Skill, cast_detail: String = "") -> void:
	heal(self_character, primary_target, skill, cast_detail)
	_apply_stat_effect(skill.resolve_targets(self_character, self_character), skill.buffed_potential_types, skill.skill_ratio, skill.duration_rounds)


# =========================================================
# 素質增益 / 減益(BUFF / DEBUFF 類型,不含攻擊)
# =========================================================

## 增益:自我為中心施放(隊長/血統/通用被動的主動增益技,ALL_ALLIES 或 RADIUS 皆適用)。
static func stat_buff(self_character: BattleCharacter, primary_target: BattleCharacter, skill: Skill, cast_detail: String = "") -> void:
	self_character.battle.log_event(SkillEvent.new(self_character, self_character, skill.name, cast_detail))
	var targets := skill.resolve_targets(self_character, self_character)
	_apply_stat_effect(targets, skill.buffed_potential_types, skill.skill_ratio, skill.duration_rounds)

## 增益 + 機制(例如常勝威名的必中效果、王者號令的減傷,這類「不改變素質數值」的加成
## 用 mechanics 表達,見 Skill.mechanics 的 CLEANSE 之外用途——目前設計表上這類複合大將技
## 的第二效果多半是敘述性的,尚未有專屬的「全隊必中/全隊減傷」機制實作,這裡先套用
## 素質增益本身,機制部分留待對應機制做出來後再接上)。
static func stat_buff_with_mechanic(self_character: BattleCharacter, primary_target: BattleCharacter, skill: Skill, cast_detail: String = "") -> void:
	stat_buff(self_character, primary_target, skill, cast_detail)
	_apply_status_mechanics(self_character, skill.resolve_targets(self_character, self_character), skill)

## 全隊技能權重暫時提升(智將韜略):跟乘勝追擊共用同一個
## BattleCharacter.apply_skill_weight_boost() 欄位,這裡是「主動施放,對全隊生效」的版本。
static func skill_weight_buff(self_character: BattleCharacter, primary_target: BattleCharacter, skill: Skill, cast_detail: String = "") -> void:
	self_character.battle.log_event(SkillEvent.new(self_character, self_character, skill.name, cast_detail))
	for ally in skill.resolve_targets(self_character, self_character):
		ally.apply_skill_weight_boost(skill.skill_ratio, skill.duration_rounds)

## 減益:以鎖定的目標為中心(單體/範圍/全體敵人皆適用)。
static func stat_debuff(self_character: BattleCharacter, primary_target: BattleCharacter, skill: Skill, cast_detail: String = "") -> void:
	self_character.battle.log_event(SkillEvent.new(self_character, primary_target, skill.name, cast_detail))
	var targets := skill.resolve_targets(self_character, primary_target)
	_apply_stat_effect(targets, skill.buffed_potential_types, skill.skill_ratio, skill.duration_rounds)

## 減益 + 機制(天譴降臨:體質削弱之餘一併封印):傷害/減益結算用 stat_debuff() 同一套,
## 結束後再對同一批目標套用機制型異常狀態,各自判定抵抗。
static func stat_debuff_with_mechanic(self_character: BattleCharacter, primary_target: BattleCharacter, skill: Skill, cast_detail: String = "") -> void:
	stat_debuff(self_character, primary_target, skill, cast_detail)
	_apply_status_mechanics(self_character, skill.resolve_targets(self_character, primary_target), skill)

## 純機制減益(無傷害、無素質變動,例如怯戰低語/封喉號令這類大將減益技):對
## ALL_ENEMIES/RADIUS 範圍套用 mechanics,每個目標各自判定抵抗。
static func mechanic_debuff(self_character: BattleCharacter, primary_target: BattleCharacter, skill: Skill, cast_detail: String = "") -> void:
	self_character.battle.log_event(SkillEvent.new(self_character, self_character, skill.name, cast_detail))
	var targets := skill.resolve_targets(self_character, self_character)
	_apply_status_mechanics(self_character, targets, skill)

## 純機制增益(無素質變動,例如常勝威名這類全隊限時破防/必定暴擊技):對 ALL_ALLIES
## 套用 mechanics,增益類不判定抵抗(見 _apply_status_mechanics()/_NEGATIVE_MECHANICS)。
static func mechanic_buff(self_character: BattleCharacter, primary_target: BattleCharacter, skill: Skill, cast_detail: String = "") -> void:
	self_character.battle.log_event(SkillEvent.new(self_character, self_character, skill.name, cast_detail))
	var targets := skill.resolve_targets(self_character, self_character)
	_apply_status_mechanics(self_character, targets, skill)


# =========================================================
# 被動(開戰套用一次,見 BattleCharacter._apply_passive_skills()/Skill.apply_passive())
# =========================================================

## 永久提升素質:通用被動的標準形狀,取代舊版逐一寫死兩個素質的 wisdom_and_valor_passive()——
## 任何素質組合都吃 skill.buffed_potential_types + skill.skill_ratio,rounds=-1(永久)。
static func passive_stat_buff(self_character: BattleCharacter, skill: Skill) -> void:
	for potential_type in skill.buffed_potential_types:
		self_character.add_stat_modifier(potential_type, skill.skill_ratio, -1)

## 永久提升異常狀態抵抗率(泰然自若):skill.skill_ratio 直接當百分點加成,見
## BattleCharacter.bonus_status_resist_percent/CombatResolver.judge_status_resist()。
static func passive_status_resist_buff(self_character: BattleCharacter, skill: Skill) -> void:
	self_character.bonus_status_resist_percent += skill.skill_ratio

## 守護/剛烈反擊/絕影迴避/共鳴擴散/連珠射術/守夢低語這類反應式武器被動:效果不在這裡
## 發生,是 CombatResolver.resolve_guard()/maybe_counter_attack()/_resolve_attack_hit()
## 的完美迴避檢查/maybe_reactive_heal()/BattleCharacter.attack() 的追加一擊與範圍擴大
## 檢查隨時反應觸發,見 Skill.mechanics 對應的 SkillMechanic 旗標。這個函式只是給
## Skill 建構子一個合法的 Callable 佔位,apply_passive() 呼叫到也不做任何事。
static func reactive_passive_noop(self_character: BattleCharacter, skill: Skill) -> void:
	pass


# =========================================================
# 六種武器攻擊入口(給 SkillBuilder.action() 綁定用,武器固定、不需要每次呼叫端自己傳)
# =========================================================

static func sword_attack(self_character: BattleCharacter, target: BattleCharacter, skill: Skill, cast_detail: String = "") -> void:
	weapon_attack(self_character, target, skill, cast_detail, GameEnums.WeaponType.SWORD)

static func bow_attack(self_character: BattleCharacter, target: BattleCharacter, skill: Skill, cast_detail: String = "") -> void:
	weapon_attack(self_character, target, skill, cast_detail, GameEnums.WeaponType.BOW)

static func shield_attack(self_character: BattleCharacter, target: BattleCharacter, skill: Skill, cast_detail: String = "") -> void:
	weapon_attack(self_character, target, skill, cast_detail, GameEnums.WeaponType.SHIELD)

static func dagger_attack(self_character: BattleCharacter, target: BattleCharacter, skill: Skill, cast_detail: String = "") -> void:
	weapon_attack(self_character, target, skill, cast_detail, GameEnums.WeaponType.DAGGER)

static func staff_attack(self_character: BattleCharacter, target: BattleCharacter, skill: Skill, cast_detail: String = "") -> void:
	weapon_attack(self_character, target, skill, cast_detail, GameEnums.WeaponType.STAFF)

static func dreamcatcher_attack(self_character: BattleCharacter, target: BattleCharacter, skill: Skill, cast_detail: String = "") -> void:
	weapon_attack(self_character, target, skill, cast_detail, GameEnums.WeaponType.DREAMCATCHER)
