class_name BattleHero
extends RefCounted

## 每回合預設移動步數
const BASE_MOVE_STEPS := 2
## 每累積這麼多敏捷,多走 1 格
const AGILITY_PER_EXTRA_STEP := 50.0

var hero: Hero
var battle: Battle

## 是否為所屬小隊的隊長:戰場上顯示金色外框,陣亡會立即結束整場戰鬥
## (見 Battle.is_decided)
var is_leader: bool

var _is_enemy: bool

var _strength_const: float = 1.0
var _agility_const: float = 1.0
var _dexterity_const: float = 1.0
var _vitality_const: float = 1.0
var _intelligence_const: float = 1.0
var _mentality_const: float = 1.0

## 戰場格子座標,由 Battle 佈陣時指定初始值,戰鬥中隨 move() 更新
var grid_pos: Vector2i

## 可施放技能表:key 為技能 id,value 為權重(action() 抽中 SKILL 時,
## 用這張表決定實際施放哪一個技能)
var action_chance_map: Dictionary = {}

func _init(p_hero: Hero, p_battle: Battle, p_is_enemy: bool, p_is_leader: bool = false) -> void:
	hero = p_hero
	battle = p_battle
	_is_enemy = p_is_enemy
	is_leader = p_is_leader
	_set_action_chance()

## 只有手持武器與技能相符(或技能沒綁武器)才能被抽到,權重直接採技能本身的基礎機率
func _set_action_chance() -> void:
	for skill in hero.skill_list:
		if hero.can_use_skill(skill):
			action_chance_map[skill.id] = skill.base_chance

## 每回合抽一次行動類型的權重表:ATTACK/DAZE/SKILL 固定各 25,
## ESCAPE 只有在 HP 低於 50% 時才會被列入(權重 25),
## CONFUSE(叛變攻擊己方)暫時移除抽選,等魅惑狀態系統接上後再開放。
func _build_action_type_chance_map() -> Dictionary:
	var map := {
		"ATTACK": 25.0,
		"DAZE": 25.0,
		"SKILL": 25.0,
	}
	if hp_ratio < 0.5:
		map["ESCAPE"] = 25.0
	return map

## 每回合的行動:先依權重抽出行動類型,再依類型決定實際行為。
## ATTACK 需要進入武器對應的攻擊距離才能出手(見 basic_attack_range),尚未進入範圍時
## 改為往目標移動;SKILL 的範圍判斷交給 _cast_random_skill(每個技能距離不同);
## DAZE 原地不動;ESCAPE(HP 低於 50% 才可能抽到)遠離目標。action_detail 是這次
## 行動類型的權重抽選過程(見 _describe_weighted_roll),一路往下傳給實際執行的
## 分支,讓戰報 UI 能在對應那行顯示「為什麼選了這個行動」。
func action() -> void:
	var target := search_enemy()
	if target == null:
		return

	var chance_map := _build_action_type_chance_map()
	var roll_info := Util.get_random_chance_item_detailed(chance_map)
	var action_type: String = roll_info.key
	var action_detail := _describe_weighted_roll(
		"%s 決定本回合行動類型" % name, chance_map, roll_info.roll, roll_info.total, action_type
	)

	match action_type:
		"DAZE":
			daze(action_detail)
		"ESCAPE":
			move_away(target, 0, action_detail)
		"SKILL":
			_cast_random_skill(target, action_detail)
		_: # "ATTACK"
			if _in_range(target, basic_attack_range):
				_kite_to_max_range(target, basic_attack_range)
				attack(target, action_detail)
			else:
				move(target, basic_attack_range, action_detail)
				if _in_range(target, basic_attack_range):
					attack(target, action_detail)

## 通用的「權重表隨機抽選」說明文字,給戰報 UI 用:列出每個選項的權重、這次骰到的值、
## 總權重、最後選中哪個。display_map 的 key 一定要是人看得懂的名字(技能 id 要先轉成
## 技能名稱,見 _skill_chance_display_map()),不要直接把 UUID 丟進來。
func _describe_weighted_roll(title: String, display_map: Dictionary, roll: float, total: float, chosen_label: String) -> String:
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
func _cast_random_skill(target: BattleHero, action_detail: String = "") -> void:
	if action_chance_map.is_empty():
		if _in_range(target, basic_attack_range):
			attack(target, action_detail)
		else:
			move(target, basic_attack_range, action_detail)
			if _in_range(target, basic_attack_range):
				attack(target, action_detail)
		return

	var skill_roll := Util.get_random_chance_item_detailed(action_chance_map)
	var skill := _find_skill_by_id(skill_roll.key)
	if skill == null:
		if _in_range(target, basic_attack_range):
			attack(target, action_detail)
		else:
			move(target, basic_attack_range, action_detail)
			if _in_range(target, basic_attack_range):
				attack(target, action_detail)
		return

	var skill_pick_detail := _describe_weighted_roll(
		"%s 選擇要施放的技能" % name, _skill_chance_display_map(), skill_roll.roll, skill_roll.total, skill.name
	)

	var target_pick := _pick_aoe_primary_target(skill)
	var skill_target: BattleHero = target_pick.target if target_pick.target != null else target
	var target_pick_detail: String = target_pick.detail if target_pick.target != null else (
		"%s 找不到更好的範圍選擇,直接改打距離最近的敵人 %s" % [name, target.name]
	)

	var cast_detail := "%s\n\n%s" % [skill_pick_detail, target_pick_detail]
	if action_detail != "":
		cast_detail = "%s\n\n%s" % [action_detail, cast_detail]

	if _in_range(skill_target, skill.range):
		_kite_to_max_range(skill_target, skill.range)
		skill.effect(self, skill_target, cast_detail)
		return

	move(skill_target, skill.range, cast_detail)
	if _in_range(skill_target, skill.range):
		skill.effect(self, skill_target, cast_detail)
	# 移動後仍搆不到:比照一般攻擊「移動不到位就不出手」,本回合到此結束。

## 把 action_chance_map(key 是技能 id)轉成「技能名稱 → 權重」給戰報 UI 顯示用,
## 不要把 UUID 直接秀給玩家看。
func _skill_chance_display_map() -> Dictionary:
	var display_map := {}
	for id in action_chance_map.keys():
		var s := _find_skill_by_id(id)
		var skill_name: String = s.name if s != null else "?"
		display_map[skill_name] = action_chance_map[id]
	return display_map

func _find_skill_by_id(id: String) -> Skill:
	for s in hero.skill_list:
		if s.id == id:
			return s
	return null

## 從存活敵人中選出「以該敵人為中心可以命中最多目標」的一個當這次施法的主要目標——
## 範圍越大、扎堆越多的方向越划算;命中數同分時(含單體技能,固定都是命中 1 個)
## 改選離自己較近的,貼近原本「打最近敵人」的直覺,減少無謂繞路。回傳值是
## {"target": BattleHero, "detail": String},沒有存活敵人時 target 為 null。
func _pick_aoe_primary_target(skill: Skill) -> Dictionary:
	var candidates := enemies
	if candidates.is_empty():
		return {"target": null, "detail": ""}

	var best: BattleHero = null
	var best_hit_count := -1
	var best_dist := -1
	var breakdown: Array[String] = []
	for candidate in candidates:
		var hit_count := skill.resolve_targets(self, candidate).size()
		var dist := _manhattan(grid_pos, candidate.grid_pos)
		breakdown.append("%s(命中%d人/距離%d)" % [candidate.name, hit_count, dist])
		if best == null or hit_count > best_hit_count or (hit_count == best_hit_count and dist < best_dist):
			best = candidate
			best_hit_count = hit_count
			best_dist = dist

	var detail := "%s 比較以每個敵人為中心可以命中的數量:%s → 選擇 %s(命中 %d 人)" % [
		name, "、".join(breakdown), best.name, best_hit_count,
	]
	return {"target": best, "detail": detail}

## CONFUSE:叛變攻擊己方隊友。目前 action() 暫時不會抽到這個類型
## (等魅惑狀態系統接上、能限定只有被魅惑時才抽得到再開放),
## 機制先保留在這裡備用;找不到可攻擊的隊友時退化成原地發呆。
func _confuse_attack() -> void:
	var living_allies := allies
	if living_allies.is_empty():
		daze()
		return

	var victim: BattleHero = Util.get_random_from_array(living_allies)
	attack(victim)

func attack(target: BattleHero, action_detail: String = "") -> void:
	var target_pick_detail := "%s 鎖定距離最近的敵人 %s(距離 %d 格)作為普攻目標" % [
		name, target.name, _manhattan(grid_pos, target.grid_pos),
	]
	var attack_detail := target_pick_detail
	if action_detail != "":
		attack_detail = "%s\n\n%s" % [action_detail, target_pick_detail]

	battle.log_event({
		"type": "attack", "actor": self, "actor_name": name,
		"target": target, "target_name": target.name, "detail": attack_detail,
	})

	var dodge_check := judge_dodge(self, target)
	if dodge_check.dodged:
		return
	var damage := SkillEffectLibrary.basic_attack_damage(self, target, hero.weapon)
	var crit_check := judge_crit(self, target)
	if crit_check.critical:
		damage *= CRIT_DAMAGE_MULTIPLIER
	target.be_attacked(damage, crit_check.critical, "%s\n\n%s" % [dodge_check.detail, crit_check.detail])

func daze(action_detail: String = "") -> void:
	battle.log_event({"type": "daze", "actor": self, "actor_name": name, "detail": action_detail})

## 往目標方向移動,最多走 move_steps 格(先水平、後垂直),一旦進入 atk_range
## (呼叫端傳入普攻距離或該次要施放的技能距離)就停止,不會多走進更近的格子;
## 途中會直接穿過己方角色(不擋路),只有敵方角色會擋路,
## 遇到敵方卡住主方向時會側移繞路,而不是直接卡死不動。
## 整趟移動只記一筆 move 事件(內含完整路徑),讓畫面端可以連續播放,
## 不必每格都停頓。
func move(target: BattleHero, atk_range: int, action_detail: String = "") -> void:
	_move_towards_or_away(target, false, atk_range, action_detail)

## 遠程攻擊(atk_range > 1)已經在射程內、但離目標比射程還近時,退到接近最遠射程再出手,
## 拉開跟敵人的距離、降低被近身反擊的風險;用 atk_range 當退場的停止條件,保證退完之後
## 仍在射程內,不會白白退出射程外浪費這次攻擊。近戰(atk_range<=1)沒有後退空間,略過。
func _kite_to_max_range(target: BattleHero, atk_range: int) -> void:
	if atk_range <= 1:
		return
	if _manhattan(grid_pos, target.grid_pos) >= atk_range:
		return
	move_away(target, atk_range)

## ESCAPE 類型用:往目標的反方向移動(遠離戰場)。max_range 預設 0,代表沒有距離上限、
## 盡量遠離戰場;遠程角色「退到最遠射程再出手」(_kite_to_max_range)則會傳入該次攻擊/
## 技能的射程,一旦退到剛好等於射程就停止,不會白白退出射程外導致這次攻擊落空。
## 其餘規則與 move() 相同(可穿過己方、只有敵方擋路、最終落腳點需淨空)。
func move_away(target: BattleHero, max_range: int = 0, action_detail: String = "") -> void:
	_move_towards_or_away(target, true, max_range, action_detail)

## action_detail 是外層(action() 的行動類型抽選)傳進來的說明前綴,可為空字串;
## 移動本身的公式(可走幾格/實際走了幾格/移動目的)一律自己組,不需要呼叫端提供。
func _move_towards_or_away(target: BattleHero, away: bool, atk_range: int, action_detail: String = "") -> void:
	var start_pos := grid_pos
	var path: Array[Vector2i] = []

	for i in range(move_steps):
		if not away and _in_range(target, atk_range):
			break
		if away and atk_range > 0 and _manhattan(grid_pos, target.grid_pos) >= atk_range:
			break

		var new_pos := _next_step(target, away)
		if new_pos == grid_pos:
			break

		grid_pos = new_pos
		path.append(new_pos)

	# 移動途中可以直接穿過己方角色,但最終落腳點不能剛好疊在任何人身上,
	# 若最後一步撞上己方角色所在位置,就退回到前一步(空格)停下。
	while not path.is_empty() and battle.is_occupied_excluding(path[path.size() - 1], self):
		path.remove_at(path.size() - 1)
		grid_pos = path[path.size() - 1] if not path.is_empty() else start_pos

	if path.is_empty():
		grid_pos = start_pos
		return

	var purpose: String
	if away and atk_range > 0:
		purpose = "退到剛好等於射程 %d 格再出手,不會退出射程外" % atk_range
	elif away:
		purpose = "HP 剩 %.0f%%,觸發撤退,盡量遠離戰場拉開距離" % (hp_ratio * 100.0)
	else:
		purpose = "朝目標移動,進入距離 ≤ %d 格才會停止" % atk_range

	var move_detail := (
		"%s %s %s,本回合最多可走 %d 格(基礎 %d ＋ 敏捷 %.1f ÷ 每 %.0f 點 +1 格),這次實際走了 %d 格\n" +
		"目的:%s"
	) % [
		name, ("遠離" if away else "接近"), target.name,
		move_steps, BASE_MOVE_STEPS, agility, AGILITY_PER_EXTRA_STEP,
		path.size(), purpose,
	]
	if action_detail != "":
		move_detail = "%s\n\n%s" % [action_detail, move_detail]

	battle.log_event({
		"type": "move", "actor": self, "actor_name": name,
		"target": target, "target_name": target.name,
		"from": start_pos, "path": path, "to": path[path.size() - 1], "away": away,
		"detail": move_detail,
	})

## 計算朝目標前進(或遠離,away=true)的下一步:優先走能縮短(或拉開)距離的主方向,
## 只有敵方角色會擋路(己方可直接穿過);若被敵方卡住,
## 改往另一軸側移繞路(挑選能讓距離更符合目的——靠近或遠離——的一側),
## 全部候選都走不了時回傳原地(呼叫端視為卡死、停止移動)。
func _next_step(target: BattleHero, away: bool) -> Vector2i:
	var dx := 0
	var dy := 0

	if target.grid_pos.x != grid_pos.x:
		dx = sign(target.grid_pos.x - grid_pos.x)
	elif target.grid_pos.y != grid_pos.y:
		dy = sign(target.grid_pos.y - grid_pos.y)

	if away:
		dx = -dx
		dy = -dy

	if dx == 0 and dy == 0:
		return grid_pos

	var primary := Vector2i(grid_pos.x + dx, grid_pos.y + dy)
	if _is_within_board(primary) and not _is_blocked_by_enemy(primary):
		return primary

	var sidesteps: Array[Vector2i] = []
	if dx != 0:
		sidesteps.append(Vector2i(grid_pos.x, grid_pos.y - 1))
		sidesteps.append(Vector2i(grid_pos.x, grid_pos.y + 1))
	else:
		sidesteps.append(Vector2i(grid_pos.x - 1, grid_pos.y))
		sidesteps.append(Vector2i(grid_pos.x + 1, grid_pos.y))

	sidesteps.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := _manhattan(a, target.grid_pos)
		var db := _manhattan(b, target.grid_pos)
		return da > db if away else da < db
	)

	for c in sidesteps:
		if _is_within_board(c) and not _is_blocked_by_enemy(c):
			return c

	return grid_pos

## 只有敵方(存活中)會擋路,己方角色不會阻擋移動路徑
func _is_blocked_by_enemy(pos: Vector2i) -> bool:
	for e in enemies:
		if e.grid_pos == pos:
			return true
	return false

func _is_within_board(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < Battle.GRID_COLS and pos.y >= 0 and pos.y < Battle.GRID_ROWS

func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

## 本回合可移動的格數:基礎 2 格,每 25 敏捷多走 1 格
var move_steps: int:
	get: return BASE_MOVE_STEPS + int(agility / AGILITY_PER_EXTRA_STEP)

## 是否進入攻擊範圍(以格子曼哈頓距離判定):atk_range 由呼叫端決定——
## 普攻依武器種類(見 basic_attack_range),技能依技能自己的 range。
func _in_range(target: BattleHero, atk_range: int) -> bool:
	var d: int = abs(target.grid_pos.x - grid_pos.x) + abs(target.grid_pos.y - grid_pos.y)
	return d <= atk_range

## 基本攻擊距離:近戰武器(劍/盾/匕首)1 格、遠程武器(弓/法杖/權杖)2 格,
## 徒手(EMPTY)比照近戰
var basic_attack_range: int:
	get: return GameEnums.WEAPON_BASIC_ATTACK_RANGE[hero.weapon]

## 找尋最近的敵人(以格子曼哈頓距離判定)
func search_enemy() -> BattleHero:
	var best: BattleHero = null
	var best_dist := -1
	for other in enemies:
		var d: int = abs(other.grid_pos.x - grid_pos.x) + abs(other.grid_pos.y - grid_pos.y)
		if best == null or d < best_dist:
			best_dist = d
			best = other
	return best

## 受到攻擊時:傷害直接扣角色本身的 HP,HP 歸零視為戰敗。is_critical 由呼叫端
## (judge_crit() 判定結果)傳入,純粹供 log_event 標記,不在這裡重算;roll_detail
## 是呼叫端組好的閃避+暴擊判定明細文字,原封不動存進事件給戰報 UI 顯示。
func be_attacked(damage: float, is_critical: bool = false, roll_detail: String = "") -> void:
	var damage_points: int = roundi(damage)
	hero.take_damage(damage_points)

	battle.log_event({
		"type": "damage", "target": self, "target_name": name,
		"damage_points": damage_points, "remaining_hp": hp, "is_critical": is_critical,
		"detail": roll_detail,
	})

	if is_disabled:
		battle.log_event({"type": "defeated", "party": self, "party_name": name})

## 判斷是否閃避：
## 魔法攻擊（法杖／權杖，見 GameEnums.WEAPON_IS_MAGIC）無視閃避，必定命中，
## 直接略過整套閃避判定。
##
## 其餘物理攻擊則依照：
##   - 防禦方 AGI（敏捷）：主要決定閃避能力
##   - 攻擊方 DEX（靈巧）：降低對方的閃避率
##
## AGI 與 DEX 數值範圍皆為 0~200。
## 基礎閃避率為 10%，AGI 每點提供 0.25% 閃避，
## DEX 每點降低 0.10% 閃避。
##
## 因此：
##   AGI 0   / DEX 0   → 10% 閃避
##   AGI 100 / DEX 0   → 35% 閃避
##   AGI 200 / DEX 0   → 60% 閃避（最高）
##
## 同時 DEX 可以抵銷部分 AGI 帶來的閃避優勢，
## 但閃避率最低不低於設定的下限，避免命中率被完全鎖死。
##
## 最終閃避率會夾在 DODGE_RATE_MIN ~ DODGE_RATE_MAX 之間，
## 使高 AGI 角色確實具有明顯的閃避優勢，
## 但不會讓低 AGI 角色在沒有任何敏捷能力的情況下仍擁有過高的基礎閃避率。
const DODGE_RATE_BASE := 10.0
const DODGE_RATE_SCALE := 0.25
const DODGE_RATE_MIN := 5.0
const DODGE_RATE_MAX := 60.0

## 回傳值是 {"dodged": bool, "detail": String}——detail 是給戰報 UI 用的完整公式說明
## (實際代入雙方數值/骰值),讓玩家滑鼠移到「閃避了攻擊」那行時能看到判定細節,
## 不要在字串裡用方括號 [ ],會被 RichTextLabel 的 BBCode 解析成標籤提早截斷。
func judge_dodge(attacker: BattleHero, defender: BattleHero) -> Dictionary:
	if GameEnums.WEAPON_IS_MAGIC[attacker.hero.weapon]:
		var magic_detail := "%s 使用魔法攻擊,無視閃避判定,必定命中" % attacker.name
		return {"dodged": false, "detail": magic_detail}

	var dodge_rate: float = clampf(
		DODGE_RATE_BASE
		+ defender.agility * DODGE_RATE_SCALE
		- attacker.dexterity * DODGE_RATE_SCALE,
		DODGE_RATE_MIN,
		DODGE_RATE_MAX
	)

	var roll := Util.get_random_float(0.0, 100.0)
	var dodged := roll < dodge_rate

	var detail := (
		"%s 骰出 %.2f,需要小於閃避率 %.2f%% 才會被 %s 閃開\n" +
		"公式:基礎 %.1f ＋ 防禦方(%s)AGI %.1f×%.2f － 攻擊方(%s)DEX %.1f×%.2f,夾在(%.0f%%~%.0f%%)之間\n" +
		"結果:%s"
	) % [
		attacker.name, roll, dodge_rate, defender.name,
		DODGE_RATE_BASE, defender.name, defender.agility, DODGE_RATE_SCALE,
		attacker.name, attacker.dexterity, DODGE_RATE_SCALE,
		DODGE_RATE_MIN, DODGE_RATE_MAX,
		("閃避成功" if dodged else "未閃避,命中"),
	]

	if dodged:
		battle.log_event({
			"type": "dodge",
			"actor": attacker,
			"actor_name": attacker.name,
			"target": defender,
			"target_name": defender.name,
			"detail": detail,
		})

	return {"dodged": dodged, "detail": detail}

## 判斷是否觸發暴擊:物理、魔法攻擊都會判定(跟只有物理才判定的 judge_dodge() 不同)。
## 攻擊方一律吃 DEX(靈巧),防禦方的抵抗素質依攻擊種類換:物理攻擊吃 VIT(體質)、
## 魔法攻擊(法杖／權杖)吃 MEN(信仰),邏輯與倍率其餘完全一致。
## 差值(DEX-抵抗素質)=0 時基礎暴擊率 15%,差值 200(DEX 拉滿 vs 抵抗掉零)封頂 70%,
## 差值 -200 保底 5%;正負兩側斜率不同,DEX 優勢拉高暴擊率比抵抗素質壓低暴擊率明顯。
const CRIT_RATE_BASE := 15.0
const CRIT_RATE_MAX := 70.0
const CRIT_RATE_MIN := 5.0
const CRIT_RATE_UP_SCALE := (CRIT_RATE_MAX - CRIT_RATE_BASE) / 200.0
const CRIT_RATE_DOWN_SCALE := (CRIT_RATE_BASE - CRIT_RATE_MIN) / 200.0
## 暴擊傷害倍率:成功暴擊時,原傷害直接乘上這個倍率。
const CRIT_DAMAGE_MULTIPLIER := 1.6

## 回傳值是 {"critical": bool, "detail": String},detail 同樣是給戰報 UI 用的完整
## 公式說明(見 judge_dodge() 的 detail 規則,一樣不能用方括號)。
func judge_crit(attacker: BattleHero, defender: BattleHero) -> Dictionary:
	var is_magic: bool = GameEnums.WEAPON_IS_MAGIC[attacker.hero.weapon]
	var resist_value: float = defender.mentality if is_magic else defender.vitality
	var resist_label := "MEN(信仰)" if is_magic else "VIT(體質)"
	var diff: float = attacker.dexterity - resist_value
	var scale := CRIT_RATE_UP_SCALE if diff >= 0.0 else CRIT_RATE_DOWN_SCALE
	var crit_rate: float = clampf(CRIT_RATE_BASE + diff * scale, CRIT_RATE_MIN, CRIT_RATE_MAX)

	var roll := Util.get_random_float(0.0, 100.0)
	var critical := roll < crit_rate

	var detail := (
		"%s 骰出 %.2f,需要小於暴擊率 %.2f%% 才會觸發暴擊\n" +
		"公式:基礎 %.1f ＋ 差值(攻擊方(%s)DEX %.1f － 防禦方(%s)%s %.1f)×%.3f,夾在(%.0f%%~%.0f%%)之間\n" +
		"結果:%s"
	) % [
		attacker.name, roll, crit_rate,
		CRIT_RATE_BASE, attacker.name, attacker.dexterity, defender.name, resist_label, resist_value, scale,
		CRIT_RATE_MIN, CRIT_RATE_MAX,
		("觸發暴擊！" if critical else "未觸發暴擊"),
	]

	return {"critical": critical, "detail": detail}

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

var strength: float:
	get: return hero.strength * _strength_const
var agility: float:
	get: return hero.agility * _agility_const
var dexterity: float:
	get: return hero.dexterity * _dexterity_const
var vitality: float:
	get: return hero.vitality * _vitality_const
var intelligence: float:
	get: return hero.intelligence * _intelligence_const
var mentality: float:
	get: return hero.mentality * _mentality_const

## 行動速度(回合排序用),暫以敏捷做為速度來源
var action_speed: float:
	get: return agility
