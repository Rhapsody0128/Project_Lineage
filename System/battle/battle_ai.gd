class_name BattleAi
extends RefCounted

## 角色每回合的行動決策(骰行動類型/選技能/AOE 選目標),從 BattleHero 搬出來——
## BattleHero.action() 變成一行轉發 BattleAi.take_turn(self),行為不變。

## 每回合抽一次行動類型的權重表:ATTACK/DAZE/SKILL 固定各 25,
## ESCAPE 只有在 HP 低於 50% 時才會被列入(權重 25),
## CONFUSE(叛變攻擊己方)暫時移除抽選,等魅惑狀態系統接上後再開放。
static func _build_action_type_chance_map(actor: BattleHero) -> Dictionary:
	var map := {
		"ATTACK": 25.0,
		"DAZE": 25.0,
		"SKILL": 25.0,
	}
	if actor.hp_ratio < 0.5:
		map["ESCAPE"] = 25.0
	return map

## 每回合的行動:先依權重抽出行動類型,再依類型決定實際行為。
## ATTACK 需要進入武器對應的攻擊距離才能出手(見 basic_attack_range),尚未進入範圍時
## 改為往目標移動;SKILL 的範圍判斷交給 _cast_random_skill(每個技能距離不同);
## DAZE 原地不動;ESCAPE(HP 低於 50% 才可能抽到)遠離目標。action_detail 是這次
## 行動類型的權重抽選過程,一路往下傳給實際執行的分支,讓戰報 UI 能在對應那行顯示
## 「為什麼選了這個行動」。
static func take_turn(actor: BattleHero) -> void:
	var target := actor.search_enemy()
	if target == null:
		return

	var chance_map := _build_action_type_chance_map(actor)
	var roll_info := Util.get_random_chance_item_detailed(chance_map)
	var action_type: String = roll_info.key
	var action_detail := _describe_weighted_roll(
		"%s 決定本回合行動類型" % actor.name, chance_map, roll_info.roll, roll_info.total, action_type
	)

	match action_type:
		"DAZE":
			actor.daze(action_detail)
		"ESCAPE":
			actor.move_away(target, 0, action_detail)
		"SKILL":
			_cast_random_skill(actor, target, action_detail)
		_: # "ATTACK"
			_attack_or_move_into_range(actor, target, actor.basic_attack_range, action_detail)

## 三處共用的「射程內就(必要時先拉開距離)攻擊,否則移動後再檢查一次」邏輯——
## action() 的普攻分支、_cast_random_skill() 的兩個退化成普攻分支,原本各自逐字複製
## 同一段 6 行程式碼,現在收斂成一個 helper。
static func _attack_or_move_into_range(actor: BattleHero, target: BattleHero, atk_range: int, action_detail: String = "") -> void:
	if actor.is_in_range(target, atk_range):
		actor.kite_to_max_range(target, atk_range)
		actor.attack(target, action_detail)
	else:
		actor.move(target, atk_range, action_detail)
		if actor.is_in_range(target, atk_range):
			actor.attack(target, action_detail)

## 通用的「權重表隨機抽選」說明文字,給戰報 UI 用:列出每個選項的權重、這次骰到的值、
## 總權重、最後選中哪個。display_map 的 key 一定要是人看得懂的名字(技能 id 要先轉成
## 技能名稱,見 _skill_chance_display_map()),不要直接把 UUID 丟進來。
static func _describe_weighted_roll(title: String, display_map: Dictionary, roll: float, total: float, chosen_label: String) -> String:
	var parts: Array[String] = []
	for key in display_map.keys():
		parts.append("%s %.1f" % [key, display_map[key]])
	return "%s\n權重:%s(共 %.1f)\n骰出 %.2f → 選到「%s」" % [
		title, "、".join(parts), total, roll, chosen_label,
	]

## SKILL 類型:依 action_chance_map 抽一個技能,再改選「以哪個敵人為中心命中數量最多」
## 的目標(見 _pick_aoe_primary_target,單體技能等同選最近敵人,行為不變),用該技能
## 自己的 range 判斷能不能出手(不夠近就先移動一次、以該技能的射程為目標距離,移動後
## 再重新檢查);沒有可用技能、或移動後仍搆不到,都退化成一般攻擊(退化仍要走一般攻擊
## 自己的距離判斷,目標改回原本 search_enemy() 給的最近敵人)。
static func _cast_random_skill(actor: BattleHero, target: BattleHero, action_detail: String = "") -> void:
	if actor.action_chance_map.is_empty():
		_attack_or_move_into_range(actor, target, actor.basic_attack_range, action_detail)
		return

	var chance_map := _current_skill_chance_map(actor)
	var skill_roll := Util.get_random_chance_item_detailed(chance_map)
	var skill := actor.find_skill_by_id(skill_roll.key)
	if skill == null:
		_attack_or_move_into_range(actor, target, actor.basic_attack_range, action_detail)
		return

	var skill_pick_detail := _describe_weighted_roll(
		"%s 選擇要施放的技能" % actor.name, _skill_chance_display_map(actor, chance_map), skill_roll.roll, skill_roll.total, skill.name
	)

	## HEAL/BUFF/DEFEND 這類技能是「對自己/全隊」生效(見 Skill._candidate_pool()),
	## 不需要鎖定敵人、不需要移動——直接以自己為施法中心立刻出手。
	if skill.skill_type in [GameEnums.SkillType.HEAL, GameEnums.SkillType.BUFF, GameEnums.SkillType.DEFEND]:
		var support_detail := "%s\n\n%s 對自身/全隊施放,無須鎖定敵人或移動" % [skill_pick_detail, actor.name]
		if action_detail != "":
			support_detail = "%s\n\n%s" % [action_detail, support_detail]
		skill.effect(actor, actor, support_detail)
		return

	var target_pick := _pick_aoe_primary_target(actor, skill)
	var skill_target: BattleHero = target_pick.target if target_pick.target != null else target
	var target_pick_detail: String = target_pick.detail if target_pick.target != null else (
		"%s 找不到更好的範圍選擇,直接改打距離最近的敵人 %s" % [actor.name, target.name]
	)

	var cast_detail := "%s\n\n%s" % [skill_pick_detail, target_pick_detail]
	if action_detail != "":
		cast_detail = "%s\n\n%s" % [action_detail, cast_detail]

	if actor.is_in_range(skill_target, skill.skill_range):
		actor.kite_to_max_range(skill_target, skill.skill_range)
		skill.effect(actor, skill_target, cast_detail)
		return

	actor.move(skill_target, skill.skill_range, cast_detail)
	if actor.is_in_range(skill_target, skill.skill_range):
		skill.effect(actor, skill_target, cast_detail)
	# 移動後仍搆不到:比照一般攻擊「移動不到位就不出手」,本回合到此結束。

## 把 chance_map(key 是技能 id)轉成「技能名稱 → 權重」給戰報 UI 顯示用,
## 不要把 UUID 直接秀給玩家看。
static func _skill_chance_display_map(actor: BattleHero, chance_map: Dictionary) -> Dictionary:
	var display_map := {}
	for id in chance_map.keys():
		var s := actor.find_skill_by_id(id)
		var skill_name: String = s.name if s != null else "?"
		display_map[skill_name] = chance_map[id]
	return display_map

## action_chance_map 是開戰時就篩好、哪些技能「能用」不會變的靜態底池;這裡在骰選前
## 動態套用會隨戰況變化的加權——目前只有「友軍有人 HP 低於 50%」時,治療類技能(HEAL)
## 權重乘上 HEAL_PRIORITY_MULTIPLIER,讓角色在隊友快死的時候更傾向去治療,
## 而不是每次都跟其他技能均勻亂骰。
const HEAL_PRIORITY_MULTIPLIER := 4.0

static func _current_skill_chance_map(actor: BattleHero) -> Dictionary:
	var ally_needs_heal := false
	for a in actor.allies:
		if a.hp_ratio < 0.5:
			ally_needs_heal = true
			break

	var chance_map := {}
	for id in actor.action_chance_map.keys():
		var s := actor.find_skill_by_id(id)
		var weight: float = actor.action_chance_map[id]
		if ally_needs_heal and s != null and s.skill_type == GameEnums.SkillType.HEAL:
			weight *= HEAL_PRIORITY_MULTIPLIER
		chance_map[id] = weight
	return chance_map

## 從存活敵人中選出「以該敵人為中心可以命中最多目標」的一個當這次施法的主要目標——
## 範圍越大、扎堆越多的方向越划算;命中數同分時(含單體技能,固定都是命中 1 個)
## 改選離自己較近的,貼近原本「打最近敵人」的直覺,減少無謂繞路。回傳值是
## {"target": BattleHero, "detail": String},沒有存活敵人時 target 為 null。
static func _pick_aoe_primary_target(actor: BattleHero, skill: Skill) -> Dictionary:
	var candidates := actor.enemies
	if candidates.is_empty():
		return {"target": null, "detail": ""}

	var best: BattleHero = null
	var best_hit_count := -1
	var best_dist := -1
	var breakdown: Array[String] = []
	for candidate in candidates:
		var hit_count := skill.resolve_targets(actor, candidate).size()
		var dist := _manhattan(actor.grid_pos, candidate.grid_pos)
		breakdown.append("%s(命中%d人/距離%d)" % [candidate.name, hit_count, dist])
		if best == null or hit_count > best_hit_count or (hit_count == best_hit_count and dist < best_dist):
			best = candidate
			best_hit_count = hit_count
			best_dist = dist

	var detail := "%s 比較以每個敵人為中心可以命中的數量:%s → 選擇 %s(命中 %d 人)" % [
		actor.name, "、".join(breakdown), best.name, best_hit_count,
	]
	return {"target": best, "detail": detail}

## CONFUSE:叛變攻擊己方隊友。目前 take_turn() 暫時不會抽到這個類型
## (等魅惑狀態系統接上、能限定只有被魅惑時才抽得到再開放),
## 機制先保留在這裡備用;找不到可攻擊的隊友時退化成原地發呆。
static func confuse_attack(actor: BattleHero) -> void:
	var living_allies := actor.allies
	if living_allies.is_empty():
		actor.daze()
		return

	var victim: BattleHero = Util.get_random_from_array(living_allies)
	actor.attack(victim)

static func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)
