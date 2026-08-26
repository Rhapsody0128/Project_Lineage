class_name BattleAi
extends RefCounted

## 角色每回合的行動決策(骰行動/選目標),從 BattleCharacter 搬出來——
## BattleCharacter.action() 變成一行轉發 BattleAi.take_turn(self),行為不變。
##
## 單一層級的情境權重骰選:普通攻擊/發呆/撤退(HP<50% 才列入)這三個固定選項,加上角色
## 已學會的每一個技能,全部攤平在同一張候選表裡依戰場需求算權重、一起比大小、一次骰選——
## 不先骰「這回合要不要用技能」、骰到才在技能之間選一次那種兩層架構。「這一刻該做什麼」
## 完全交給權重高低決定,骰選本身只負責在權重接近的候選之間保留一點不確定性(見
## _shortlist_top_candidates()),不是先射箭再畫靶。

## 固定基礎權重:普通攻擊隨時列入候選,撤退只有 HP 低於 ESCAPE_HP_THRESHOLD(或正處於
## 恐懼狀態,見下方 FEAR_* 常數)才列入,兩者都是「真正的戰術選項」,權重跟其他候選一樣
## 公平比大小。發呆刻意壓得很低——它不是一個正常戰術選項,是「找不到任何值得做的事」時
## 才會浮上來的保底值(AI 最低行動意願),不該常態性跟攻擊/技能搶候選名額,只有在角色
## 技能池普遍疲弱(全部技能權重都很低)時才有機會被骰到。
const ATTACK_BASE_WEIGHT := 25.0
const DAZE_BASE_WEIGHT := 5.0
const ESCAPE_BASE_WEIGHT := 25.0
const ESCAPE_HP_THRESHOLD := 0.5

## 恐懼(見 BattleCharacter.apply_fear()/is_feared)不是讓角色隨機誤擊或亂選,而是直接
## 放大「逃跑」「發呆」這兩個選項的權重——恐懼中的角色即使 HP 還健康也會把撤退列入候選
## (不受 ESCAPE_HP_THRESHOLD 限制),逃跑跟發呆的權重各自再乘上對應倍數。
const FEAR_ESCAPE_WEIGHT_MULTIPLIER := 3.0
const FEAR_DAZE_WEIGHT_MULTIPLIER := 3.0

## 候選表用的固定字串 key,跟技能 id(UUID)不會撞到,可以安心攤平在同一張表裡。
const ACTION_ATTACK := "ATTACK"
const ACTION_DAZE := "DAZE"
const ACTION_ESCAPE := "ESCAPE"

## 每回合的行動:見檔頭註解,單一層級的情境權重骰選。target 只在 SKILL/ATTACK 分支需要,
## ESCAPE 也拿它算遠離方向;找不到敵人(全滅)時整回合直接不出手。
static func take_turn(actor: BattleCharacter) -> void:
	var target := actor.search_enemy()
	if target == null:
		return

	var scored := _build_action_chance_map(actor)
	var chance_map := _shortlist_top_candidates(scored.weights)
	if chance_map.is_empty():
		return

	var roll_info := Util.get_random_chance_item_detailed(chance_map)
	var action_detail := "%s\n\n%s" % [
		_describe_weighted_roll(
			"%s 決定本回合行動" % actor.name, _action_chance_display_map(actor, chance_map),
			roll_info.roll, roll_info.total, _action_label(actor, roll_info.key)
		),
		_describe_action_weight_reasons(actor, chance_map, scored.notes),
	]

	match roll_info.key:
		ACTION_DAZE:
			actor.daze(action_detail)
		ACTION_ESCAPE:
			actor.move_away(target, 0, action_detail)
		ACTION_ATTACK:
			var attack_pick := _pick_primary_target(actor, func(_c): return 1)
			var attack_target: BattleCharacter = attack_pick.target if attack_pick.target != null else target
			var attack_detail := action_detail if attack_pick.target == null else "%s\n\n%s" % [action_detail, attack_pick.detail]
			_attack_or_move_into_range(actor, attack_target, actor.basic_attack_range, attack_detail)
		_:
			var skill := actor.find_skill_by_id(roll_info.key)
			if skill == null:
				_attack_or_move_into_range(actor, target, actor.basic_attack_range, action_detail)
			else:
				_cast_skill(actor, target, skill, action_detail)

## 三處共用的「射程內就(必要時先拉開距離)攻擊,否則移動後再檢查一次」邏輯——
## 普攻分支、_cast_skill() 的兩個退化成普攻分支,原本各自逐字複製同一段 6 行程式碼,
## 現在收斂成一個 helper。
static func _attack_or_move_into_range(actor: BattleCharacter, target: BattleCharacter, atk_range: int, action_detail: String = "") -> void:
	if actor.is_in_range(target, atk_range):
		actor.kite_to_max_range(target, atk_range)
		actor.attack(target, action_detail)
	else:
		actor.move(target, atk_range, action_detail)
		if actor.is_in_range(target, atk_range):
			actor.attack(target, action_detail)

## 通用的「權重表隨機抽選」說明文字,給戰報 UI 用:列出每個選項的權重、這次骰到的值、
## 總權重、最後選中哪個。display_map 的 key 一定要是人看得懂的名字(sentinel/技能 id
## 要先轉成中文標籤,見 _action_chance_display_map()),不要直接把 UUID 丟進來。
static func _describe_weighted_roll(title: String, display_map: Dictionary, roll: float, total: float, chosen_label: String) -> String:
	var parts: Array[String] = []
	for key in display_map.keys():
		parts.append("%s %.1f" % [key, display_map[key]])
	return "%s\n權重:%s(共 %.1f)\n骰出 %.2f → 選到「%s」" % [
		title, "、".join(parts), total, roll, chosen_label,
	]

## 骰選行動前先收斂候選:只留下權重最高的前 ACTION_SHORTLIST_SIZE 個選項(權重 <= 0 的
## 選項——例如沒人受傷的治療技——直接排除,不占候選名額),再對這個縮小後的候選名單做
## 加權隨機。這樣「數值最高的選項」不會每次都被選中(候選裡權重較低的仍有機會雀屏中選),
## 也不會被「明明用不上的技能」稀釋掉整體機率——比純粹的全體加權隨機更接近「大致聰明,
## 偶爾做不同選擇」,又比「永遠選分數最高」保留一點不可預測性。
const ACTION_SHORTLIST_SIZE := 3

static func _shortlist_top_candidates(chance_map: Dictionary) -> Dictionary:
	var entries: Array = []
	for id in chance_map.keys():
		var weight: float = chance_map[id]
		if weight > 0.0:
			entries.append({"id": id, "weight": weight})
	entries.sort_custom(func(a, b): return a.weight > b.weight)

	var shortlisted := {}
	for i in range(mini(ACTION_SHORTLIST_SIZE, entries.size())):
		shortlisted[entries[i].id] = entries[i].weight
	return shortlisted

## candidate key(ACTION_ATTACK/ACTION_DAZE/ACTION_ESCAPE 或技能 id)轉成人看得懂的
## 中文標籤,給戰報 UI 用,不要把 UUID 或英文 sentinel 直接秀給玩家看。
static func _action_label(actor: BattleCharacter, key: String) -> String:
	match key:
		ACTION_ATTACK:
			return "普通攻擊"
		ACTION_DAZE:
			return "發呆"
		ACTION_ESCAPE:
			return "撤退"
		_:
			var s := actor.find_skill_by_id(key)
			return s.name if s != null else "?"

static func _action_chance_display_map(actor: BattleCharacter, chance_map: Dictionary) -> Dictionary:
	var display_map := {}
	for key in chance_map.keys():
		display_map[_action_label(actor, key)] = chance_map[key]
	return display_map

## 候選名單裡每個選項的權重是怎麼算出來的,一行一個,給戰報 UI 用——對照
## _build_action_chance_map() 回傳的 notes,只列出這次真的進入候選(shortlisted_map)
## 的選項,不必把整份候選池的細節都攤開來。
static func _describe_action_weight_reasons(actor: BattleCharacter, shortlisted_map: Dictionary, notes: Dictionary) -> String:
	var lines: Array[String] = []
	for id in shortlisted_map.keys():
		lines.append("%s:%s" % [_action_label(actor, id), notes.get(id, "—")])
	return "權重明細:\n%s" % "\n".join(lines)

## 這回合所有候選行動的權重與說明:普通攻擊/發呆/撤退(HP<50% 才列入)這三個固定選項,
## 加上角色已學會的每一個技能——全部攤平在同一張表裡一起比大小。技能各自的情境加權
## (HEAL 依隊友受傷程度、BUFF/DEBUFF 已生效打折、ATTACK 依敵人數量)沿用原本邏輯,最後
## 統一乘上被動技能宣告的 AI 個性乘數(見 BattleCharacter.ai_personality_multiplier()/
## Skill.ai_weight_multipliers)——普通攻擊比照 GameEnums.SkillType.ATTACK 一起吃這個
## 乘數,一個「好戰」被動同時影響普攻跟攻擊技能的偏好,不必特別分開處理。
##
## 回傳 {"weights": Dictionary(key→最終權重,給 Util 抽選用), "notes": Dictionary(key→
## 這個權重怎麼算出來的一行說明,給戰報 UI 用)}——兩份資料同一個迴圈算出來,不會各自
## 維護一份導致跟實際骰選邏輯兜不起來。
static func _build_action_chance_map(actor: BattleCharacter) -> Dictionary:
	var weights := {}
	var notes := {}

	var attack_personality: float = actor.ai_personality_multiplier(GameEnums.SkillType.ATTACK)
	weights[ACTION_ATTACK] = ATTACK_BASE_WEIGHT * attack_personality
	notes[ACTION_ATTACK] = "固定基礎權重 %.1f" % ATTACK_BASE_WEIGHT
	if not is_equal_approx(attack_personality, 1.0):
		notes[ACTION_ATTACK] += "\n個性乘數 ×%.2f" % attack_personality

	weights[ACTION_DAZE] = DAZE_BASE_WEIGHT * (FEAR_DAZE_WEIGHT_MULTIPLIER if actor.is_feared else 1.0)
	notes[ACTION_DAZE] = "固定基礎權重 %.1f" % DAZE_BASE_WEIGHT
	if actor.is_feared:
		notes[ACTION_DAZE] += "\n恐懼中,權重 ×%.1f" % FEAR_DAZE_WEIGHT_MULTIPLIER

	if actor.hp_ratio < ESCAPE_HP_THRESHOLD or actor.is_feared:
		weights[ACTION_ESCAPE] = ESCAPE_BASE_WEIGHT * (FEAR_ESCAPE_WEIGHT_MULTIPLIER if actor.is_feared else 1.0)
		var escape_reason := "HP 低於 %.0f%%" % (ESCAPE_HP_THRESHOLD * 100.0) if actor.hp_ratio < ESCAPE_HP_THRESHOLD else "恐懼中"
		notes[ACTION_ESCAPE] = "%s,列入撤退選項,固定權重 %.1f" % [escape_reason, ESCAPE_BASE_WEIGHT]
		if actor.is_feared:
			notes[ACTION_ESCAPE] += "\n恐懼中,權重 ×%.1f" % FEAR_ESCAPE_WEIGHT_MULTIPLIER

	## 封印中:所有技能直接排除出候選(等同只剩普攻/發呆/撤退可選),不逐一計算權重。
	if actor.is_sealed:
		return {"weights": weights, "notes": notes}

	for id in actor.action_chance_map.keys():
		var s := actor.find_skill_by_id(id)
		var base_weight: float = actor.action_chance_map[id]
		var weight := base_weight
		var note := "維持基礎權重 %.1f" % base_weight
		if s != null:
			match s.skill_type:
				GameEnums.SkillType.HEAL:
					weight = _heal_skill_weight(actor, s)
					note = "治療需求動態權重 %.1f(不吃技能自身基礎權重)" % weight
				GameEnums.SkillType.BUFF, GameEnums.SkillType.DEBUFF:
					weight = _stat_skill_weight(actor, s, base_weight)
					note = ("目標已全數生效同一效果,權重打折為 %.1f" % weight) if weight != base_weight else note
				GameEnums.SkillType.ATTACK:
					weight = _attack_skill_weight(actor, s, base_weight)
					note = ("範圍技依實際可命中人數調整為 %.1f" % weight) if weight != base_weight else note
			var personality: float = actor.ai_personality_multiplier(s.skill_type)
			if not is_equal_approx(personality, 1.0):
				note += "\n個性乘數 ×%.2f" % personality
			weight *= personality
			var weight_boost: float = actor.skill_weight_boost_multiplier
			if not is_equal_approx(weight_boost, 1.0):
				note += "\n技能權重加成 ×%.2f" % weight_boost
				weight *= weight_boost
		weights[id] = weight
		notes[id] = note

	return {"weights": weights, "notes": notes}

## 已經骰選出要施放的技能後,實際出手。HEAL/BUFF/DEFEND 這類技能是「對自己/全隊」生效
## (見 Skill._candidate_pool()),不需要鎖定敵人、不需要移動——直接以自己為施法中心
## 立刻出手;其餘技能改用 _pick_primary_target() 依命中人數/血量/大將/距離選目標,用該
## 技能自己的 range 判斷能不能出手(不夠近就先移動一次、以該技能的射程為目標距離,移動後
## 再重新檢查);移動後仍搆不到就比照一般攻擊「移動不到位就不出手」,本回合到此結束。
static func _cast_skill(actor: BattleCharacter, target: BattleCharacter, skill: Skill, action_detail: String = "") -> void:
	## 不需要鎖定敵人、以自己為施法中心的技能:skill_range == 0 本身就是「站在原地就能
	## 施放」的宣告(HEAL/BUFF/DEFEND/SHIELD 全隊技、大將的 ALL_ENEMIES 全體減益技、
	## 血統/法杖的自我中心範圍攻擊皆同一套判斷),不需要另外照 skill_type 分支——
	## is_in_range(target, 0) 對任何敵人幾乎不可能成立,這類技能本來就不該走「鎖定/移動」
	## 那條路。
	if skill.skill_range == 0:
		var support_detail := "%s\n\n%s 對自身/全隊施放,無須鎖定敵人或移動" % [action_detail, actor.name]
		skill.effect(actor, actor, support_detail)
		return

	var target_pick := _pick_primary_target(actor, func(candidate): return skill.resolve_targets(actor, candidate).size())
	var skill_target: BattleCharacter = target_pick.target if target_pick.target != null else target
	var target_pick_detail: String = target_pick.detail if target_pick.target != null else (
		"%s 找不到更好的範圍選擇,直接改打距離最近的敵人 %s" % [actor.name, target.name]
	)

	var cast_detail := "%s\n\n%s" % [action_detail, target_pick_detail]

	if actor.is_in_range(skill_target, skill.skill_range):
		actor.kite_to_max_range(skill_target, skill.skill_range)
		skill.effect(actor, skill_target, cast_detail)
		return

	actor.move(skill_target, skill.skill_range, cast_detail)
	if actor.is_in_range(skill_target, skill.skill_range):
		skill.effect(actor, skill_target, cast_detail)
	# 移動後仍搆不到:比照一般攻擊「移動不到位就不出手」,本回合到此結束。

## action_chance_map 是開戰時就篩好、哪些技能「能用」不會變的靜態底池;這裡在骰選前
## 動態套用會隨戰況變化的加權——治療類技能(HEAL)不吃技能本身的 base_chance,
## 改成固定三段權重:治得到的人全滿血就不用治療(0),治得到的人裡有人受傷但都還沒到
## 半血只是普通程度(HEAL_WEIGHT_CAN_HEAL),治得到的人裡有人受傷到半血以下就優先處理
## (HEAL_WEIGHT_BELOW_HALF)。「治得到的人」一律用 skill.resolve_targets() 算(HEAL
## 不需要移動,直接以施法者目前位置為中心判定範圍,見 _cast_skill()),不是看
## 全隊受傷狀況——隊友雖然少血但站在治療範圍外,這次骰選就不該把權重往上推。
const HEAL_WEIGHT_NO_INJURY := 0.0
const HEAL_WEIGHT_CAN_HEAL := 20.0
const HEAL_WEIGHT_BELOW_HALF := 50.0

## 依「這個治療技能實際治得到的人」(skill.resolve_targets(actor, actor))目前的
## 受傷程度,決定這個技能這回合該給多少固定權重。
static func _heal_skill_weight(actor: BattleCharacter, skill: Skill) -> float:
	var reachable := skill.resolve_targets(actor, actor)
	var any_injured := false
	for target in reachable:
		if target.hp_ratio < 0.5:
			return HEAL_WEIGHT_BELOW_HALF
		if target.hp_ratio < 1.0:
			any_injured = true
	return HEAL_WEIGHT_CAN_HEAL if any_injured else HEAL_WEIGHT_NO_INJURY

## D. 大將之風/E. 降咒 這類「素質增益/減益」技能:對已經生效同一組修正的目標重複
## 施放,只會把剩餘回合數刷新回滿(見 BattleCharacter.add_stat_modifier() 的「續時不疊加」
## 註解),不會疊加出更強的效果——這次打得到的人如果早就全部生效同一個 buff/debuff,
## 這次骰選就該把權重打折,不要對著全隊都已經飄著箭頭的隊友一直重放同一招。
## 只看「打得到的人是不是全部都已經生效」,只要還有一個沒中,價值還在,權重不打折。
const STAT_SKILL_ACTIVE_DISCOUNT := 0.15

## DEBUFF 還沒骰選出實際目標(_pick_aoe_primary_target 要等技能選定後才跑),這裡先用
## 「目前離自己最近的敵人」概略估算範圍內的人,跟實際施放時可能選到的目標略有出入,
## 但夠讓 AI 判斷「這一帶大概是不是已經被降咒過」,不需要為了精準而讓骰選邏輯反過來
## 依賴目標選擇邏輯。
static func _stat_skill_weight(actor: BattleCharacter, skill: Skill, base_weight: float) -> float:
	if skill.buffed_potential_types.is_empty():
		return base_weight

	var is_buff := skill.skill_type == GameEnums.SkillType.BUFF
	var reference_target := actor if is_buff else actor.search_enemy()
	if reference_target == null:
		return base_weight

	var targets := skill.resolve_targets(actor, reference_target)
	if targets.is_empty():
		return base_weight

	var representative_type: int = skill.buffed_potential_types[0]
	for target in targets:
		if not target.has_active_stat_modifier(representative_type, is_buff):
			return base_weight

	return base_weight * STAT_SKILL_ACTIVE_DISCOUNT

## 範圍技(RADIUS/LINE/SQUARE)划不划算要看「以最划算的位置為中心,實際上打得到幾個人」
## (_best_aoe_hit_count()),不能只看存活敵人總數——敵人分散在地圖各處時,即使數量很多,
## AOE 實際可能只打得到 1 個,那就該跟單體技一樣看待,不該白白加權;反過來敵人不算多但
## 剛好擠在一起,一樣能算出真正的命中數、值得加權。單體技(SINGLE)不吃這個估算,維持
## 技能本身的基礎權重不變。
const AOE_FAVOR_HIT_COUNT := 3
const AOE_PENALIZE_HIT_COUNT := 1
const AOE_WEIGHT_BONUS := 2.0
const AOE_WEIGHT_PENALTY := 0.5

## 這個技能在目前戰場上,以最划算的敵人為中心,實際上打得到幾個人——跟
## _pick_primary_target() 共用同一套「以每個敵人為中心算命中數」概念,這裡只要
## 最大值本身,不需要目標是誰或目標價值評分,兩邊分開算、不共用同一次迴圈結果。
static func _best_aoe_hit_count(actor: BattleCharacter, skill: Skill) -> int:
	var best := 0
	for candidate in actor.enemies:
		best = maxi(best, skill.resolve_targets(actor, candidate).size())
	return best

static func _attack_skill_weight(actor: BattleCharacter, skill: Skill, base_weight: float) -> float:
	if skill.area_shape == GameEnums.AreaShape.SINGLE:
		return base_weight

	var hit_count := _best_aoe_hit_count(actor, skill)
	if hit_count >= AOE_FAVOR_HIT_COUNT:
		return base_weight * AOE_WEIGHT_BONUS
	if hit_count <= AOE_PENALIZE_HIT_COUNT:
		return base_weight * AOE_WEIGHT_PENALTY
	return base_weight

## 目標價值評分:命中人數(get_hit_count 算出來的,單體攻擊/單體技能固定是 1)乘上
## TARGET_HIT_COUNT_WEIGHT 之後分數差距很大,是壓倒性的主要因素——多打中一個人就是
## +100 分,幾乎不可能被其他因素翻盤;低 HP(越接近戰敗分數越高)、距離遠近只在命中
## 人數接近時才決定挑哪一個。刻意不吃是否為敵方大將——大將沒有任何選中加成,跟其他
## 目標公平競爭,避免 AI 集火秒殺大將。
const TARGET_HIT_COUNT_WEIGHT := 100.0
const TARGET_LOW_HP_WEIGHT := 30.0
const TARGET_DISTANCE_PENALTY := 2.0

## 從存活敵人中選出這次攻擊/施法的主要目標,依「命中人數／血量／距離」綜合評分——
## 單體攻擊/單體技能(get_hit_count 對每個候選都回傳 1)等於只看血量/距離這兩項,
## 範圍技(get_hit_count 讀 skill.resolve_targets() 算實際命中數)則以命中人數為壓倒性
## 主因,其餘兩項只在命中人數接近時才發揮影響力。回傳值是
## {"target": BattleCharacter, "detail": String},沒有存活敵人時 target 為 null。
static func _pick_primary_target(actor: BattleCharacter, get_hit_count: Callable) -> Dictionary:
	var candidates := actor.enemies
	if candidates.is_empty():
		return {"target": null, "detail": ""}

	if actor.taunted_by != null and not actor.taunted_by.is_disabled:
		return {
			"target": actor.taunted_by,
			"detail": "%s 正被 %s 嘲諷,強制以其為目標" % [actor.name, actor.taunted_by.name],
		}

	var best: BattleCharacter = null
	var best_score := -INF
	var breakdown: Array[String] = []
	for candidate in candidates:
		var hit_count: int = get_hit_count.call(candidate)
		var dist := _manhattan(actor.grid_pos, candidate.grid_pos)
		var low_hp_bonus := (1.0 - candidate.hp_ratio) * TARGET_LOW_HP_WEIGHT
		var score: float = hit_count * TARGET_HIT_COUNT_WEIGHT + low_hp_bonus - dist * TARGET_DISTANCE_PENALTY
		breakdown.append("%s(命中%d人/HP%.0f%%/距離%d→%.1f分)" % [
			candidate.name, hit_count, candidate.hp_ratio * 100.0, dist, score,
		])
		if best == null or score > best_score:
			best = candidate
			best_score = score

	var detail := "%s 綜合比較命中人數／血量／距離:%s → 選擇 %s" % [
		actor.name, "、".join(breakdown), best.name,
	]
	return {"target": best, "detail": detail}

## CONFUSE:叛變攻擊己方隊友。目前 take_turn() 暫時不會抽到這個類型
## (等魅惑狀態系統接上、能限定只有被魅惑時才抽得到再開放),
## 機制先保留在這裡備用;找不到可攻擊的隊友時退化成原地發呆。
static func confuse_attack(actor: BattleCharacter) -> void:
	var living_allies := actor.allies
	if living_allies.is_empty():
		actor.daze()
		return

	var victim: BattleCharacter = Util.get_random_from_array(living_allies)
	actor.attack(victim)

static func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)
