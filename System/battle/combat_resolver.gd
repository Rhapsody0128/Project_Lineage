class_name CombatResolver
extends RefCounted

## 戰鬥判定共用服務:閃避/暴擊/守護判定與傷害/治療施放。BattleCharacter 的一般攻擊
## (attack())與 SkillEffectLibrary 的技能效果都呼叫這裡,不再互相呼叫對方——
## 原本 BattleCharacter ↔ SkillEffectLibrary 雙向耦合,現在收斂成兩邊都指向這個共用底層。
## 公式/常數原封不動從 BattleCharacter 搬過來,行為不變。

## 判斷是否閃避:
## 魔法攻擊(法杖／捕夢網,見 GameEnums.WEAPON_IS_MAGIC)無視閃避,必定命中,
## 直接略過整套閃避判定。
##
## 其餘物理攻擊則依照:
##   - 防禦方 AGI(敏捷):主要決定閃避能力
##   - 攻擊方 DEX(靈巧):降低對方的閃避率
##
## AGI 與 DEX 數值範圍皆為 0~200。
## 基礎閃避率為 10%,AGI 每點提供 0.25% 閃避,DEX 每點降低 0.10% 閃避。
## 最終閃避率夾在 DODGE_RATE_MIN ~ DODGE_RATE_MAX 之間。
const DODGE_RATE_BASE := 10.0
const DODGE_RATE_SCALE := 0.25
const DODGE_RATE_MIN := 5.0
const DODGE_RATE_MAX := 60.0

## 判斷是否觸發暴擊:物理、魔法攻擊都會判定(跟只有物理才判定的 judge_dodge() 不同)。
## 攻擊方一律吃 DEX(靈巧),防禦方的抵抗素質依攻擊種類換:物理攻擊吃 VIT(體質)、
## 魔法攻擊(法杖／捕夢網)吃 MEN(信仰)。差值(DEX-抵抗素質)=0 時基礎暴擊率 15%,
## 差值 200(DEX 拉滿 vs 抵抗掉零)封頂 70%,差值 -200 保底 5%;正負兩側斜率不同,
## DEX 優勢拉高暴擊率比抵抗素質壓低暴擊率明顯。
const CRIT_RATE_BASE := 15.0
const CRIT_RATE_MAX := 70.0
const CRIT_RATE_MIN := 5.0
const CRIT_RATE_UP_SCALE := (CRIT_RATE_MAX - CRIT_RATE_BASE) / 200.0
const CRIT_RATE_DOWN_SCALE := (CRIT_RATE_BASE - CRIT_RATE_MIN) / 200.0
## 暴擊傷害倍率:成功暴擊時,原傷害直接乘上這個倍率。
const CRIT_DAMAGE_MULTIPLIER := 1.6

## B. 守護:盾系角色的反應式能力,在「單體」物理攻擊命中判定前檢查——魔法攻擊無視
## (跟閃避/一般判定同一套設計)。original_target 存活隊友(allies,含自己這隊,不含
## original_target 自己)裡符合以下條件的,依序判定:手持盾、學會守護技能
## (Skill.is_guard_skill)、與 original_target 距離 ≤ GUARD_RANGE。依守護者 VIT
## 換算機率(200 VIT 時封頂 70%,線性正比),第一個骰成功的人頂替受擊,傷害再乘上
## GUARD_DAMAGE_MULTIPLIER(打 7 折);全部沒人頂替就回傳原目標(damage_multiplier=1.0)。
const GUARD_RANGE := 3
const GUARD_RATE_PER_VIT := 0.35 # 70 / 200,VIT 200 時封頂 70%
const GUARD_RATE_MAX := 70.0
const GUARD_DAMAGE_MULTIPLIER := 0.7

## detail 是給戰報 UI 用的完整公式說明(實際代入雙方數值/骰值),讓玩家滑鼠移到
## 「閃避了攻擊」那行時能看到判定細節,不要在字串裡用方括號 [ ],會被 RichTextLabel
## 的 BBCode 解析成標籤提早截斷。
static func judge_dodge(attacker: BattleCharacter, defender: BattleCharacter) -> DodgeResult:
	if GameEnums.WEAPON_IS_MAGIC[attacker.character.weapon]:
		var magic_detail := "%s 使用魔法攻擊,無視閃避判定,必定命中" % attacker.name
		return DodgeResult.new(false, magic_detail)

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
		attacker.battle.log_event(DodgeEvent.new(attacker, defender, detail))

	return DodgeResult.new(dodged, detail)

## detail 同樣是給戰報 UI 用的完整公式說明(見 judge_dodge() 的 detail 規則,一樣不能
## 用方括號)。
static func judge_crit(attacker: BattleCharacter, defender: BattleCharacter) -> CritResult:
	var is_magic: bool = GameEnums.WEAPON_IS_MAGIC[attacker.character.weapon]
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

	return CritResult.new(critical, detail)

## 恐懼/封印/攏絡這類控制型異常狀態施加前的抵抗判定:意志(MEN/精神)越高,抵抗機率
## 越高——跟 resolve_guard() 的 VIT 換算守護機率同一種公式(MEN 200 時封頂 70%,線性
## 正比),抵抗成功的目標不會被施加狀態,呼叫端(SkillEffectLibrary 的效果 function)
## 要在骰成功抵抗時跳過套用。這裡只判定「抵不抵抗得住」,不管是哪一種異常狀態,狀態
## 本身的效果/持續回合交給呼叫端決定。
const STATUS_RESIST_RATE_PER_MEN := 0.35 # 70 / 200,MEN 200 時封頂 70%
const STATUS_RESIST_RATE_MAX := 70.0

static func judge_status_resist(defender: BattleCharacter) -> StatusResistResult:
	var resist_rate: float = clampf(
		defender.mentality * STATUS_RESIST_RATE_PER_MEN + defender.bonus_status_resist_percent,
		0.0, STATUS_RESIST_RATE_MAX
	)
	var roll := Util.get_random_float(0.0, 100.0)
	var resisted := roll < resist_rate

	var detail := (
		"%s 骰出 %.2f,需要小於抵抗率 %.2f%% 才會抵抗成功\n" +
		"公式:意志(%s)MEN %.1f×%.2f ＋ 被動加成 %.1f,封頂 %.0f%%\n" +
		"結果:%s"
	) % [
		defender.name, roll, resist_rate,
		defender.name, defender.mentality, STATUS_RESIST_RATE_PER_MEN, defender.bonus_status_resist_percent, STATUS_RESIST_RATE_MAX,
		("抵抗成功!" if resisted else "抵抗失敗,異常狀態生效"),
	]

	return StatusResistResult.new(resisted, detail)

## 反擊/完美迴避/反應治療/普通攻擊追加一擊/普通攻擊範圍擴大——這幾個武器被動的「機制」
## 共通點是同一種形狀:一個固定觸發機率(設計上直接寫在 Skill.base_chance,武器被動技能
## 不吃行動骰選,這個欄位在這裡改當作純粹的觸發機率用),骰中就發動、骰不中就沒事,不需要
## 各自寫一個判定函式再各自组一份 detail 字串。呼叫端(SkillEffectLibrary)自己決定發動
## 後實際要做什麼(反擊傷害/治療量/追加一擊/擴大範圍)。
static func judge_reactive_trigger(actor_name: String, trigger_rate: float) -> ReactiveTriggerResult:
	var roll := Util.get_random_float(0.0, 100.0)
	var triggered := roll < trigger_rate

	var detail := (
		"%s 骰出 %.2f,需要小於觸發機率 %.2f%% 才會發動\n結果:%s"
	) % [actor_name, roll, trigger_rate, ("發動！" if triggered else "未發動")]

	return ReactiveTriggerResult.new(triggered, detail)

## 回傳值見 GuardResult。
static func resolve_guard(original_target: BattleCharacter, attacker: BattleCharacter) -> GuardResult:
	var no_guard := GuardResult.new(original_target, "", 1.0)

	if GameEnums.WEAPON_IS_MAGIC[attacker.character.weapon]:
		return no_guard

	for guardian in original_target.allies:
		if guardian.character.weapon != GameEnums.WeaponType.SHIELD:
			continue
		if not guardian.character.knows_guard_skill():
			continue
		if Util.manhattan_distance(guardian.grid_pos, original_target.grid_pos) > GUARD_RANGE:
			continue

		var guard_rate: float = clampf(guardian.vitality * GUARD_RATE_PER_VIT, 0.0, GUARD_RATE_MAX)
		var roll := Util.get_random_float(0.0, 100.0)
		var triggered := roll < guard_rate

		var detail := (
			"%s 骰出 %.2f,需要小於守護機率 %.2f%% 才會頂替 %s 承受這次攻擊\n" +
			"公式:守護方(%s)VIT %.1f×%.2f,封頂 %.0f%%\n" +
			"結果:%s"
		) % [
			guardian.name, roll, guard_rate, original_target.name,
			guardian.name, guardian.vitality, GUARD_RATE_PER_VIT, GUARD_RATE_MAX,
			("守護成功！" if triggered else "守護失敗"),
		]

		if not triggered:
			continue

		guardian.battle.log_event(GuardEvent.new(guardian, original_target, attacker, "守護", detail))
		return GuardResult.new(guardian, detail, GUARD_DAMAGE_MULTIPLIER)

	return no_guard

## 傷害先扣護盾(BattleCharacter.shield_points,見該欄位註解),護盾扣完才傷 HP,
## HP 歸零視為戰敗(記一筆 DefeatedEvent)。is_critical 由呼叫端(judge_crit() 判定結果)
## 傳入,純粹供事件標記,不在這裡重算;detail 是呼叫端組好的閃避+暴擊判定明細文字,
## 原封不動存進事件給戰報 UI 顯示(護盾吸收的說明另外附加,不干擾原本的判定明細)。
## 減傷被動(絕境求生/身經百戰):skill.skill_ratio 是減傷比例、skill.secondary_ratio 是
## 觸發門檻(以 hp_ratio 表示,0.0=無條件生效,例如身經百戰;0.3=HP<30% 才生效,例如
## 絕境求生)。在護盾吸收之前先打折,減傷跟護盾兩者都吃得到、不互相排斥。
static func _apply_damage_reduction(target: BattleCharacter, damage: float) -> float:
	var skill := target.character.find_skill_with_mechanic(GameEnums.SkillMechanic.DAMAGE_REDUCTION)
	if skill == null:
		return damage
	if skill.secondary_ratio > 0.0 and target.hp_ratio >= skill.secondary_ratio:
		return damage
	return damage * (1.0 - skill.skill_ratio)

static func apply_damage(target: BattleCharacter, damage_in: float, is_critical: bool = false, detail: String = "") -> void:
	var damage := _apply_damage_reduction(target, damage_in)
	var remaining_damage := damage
	if target.shield_points > 0.0:
		var absorbed := minf(target.shield_points, remaining_damage)
		target.shield_points -= absorbed
		remaining_damage -= absorbed
		detail += "\n\n%s 的護盾吸收 %.0f 點傷害,剩餘護盾 %.0f" % [target.name, absorbed, target.shield_points]

	var damage_points: int = roundi(remaining_damage)
	target.character.take_damage(damage_points)

	target.battle.log_event(DamageEvent.new(target, damage_points, target.hp, is_critical, detail, roundi(target.shield_points)))

	if target.is_disabled:
		target.battle.log_event(DefeatedEvent.new(target))

## 降治療中的目標,受到的治療效果打折扣(見 BattleCharacter.is_healing_reduced/
## HEAL_DOWN_MULTIPLIER)。
const HEAL_DOWN_MULTIPLIER := 0.5

## 恢復 HP,不會超過上限(Character.heal() 負責夾限);detail 是呼叫端組好的治療量公式說明,
## 原封不動存進事件給戰報 UI 顯示(降治療的折扣另外附加說明)。
static func apply_heal(target: BattleCharacter, amount: float, detail: String = "") -> void:
	var effective_amount := amount
	if target.is_healing_reduced:
		effective_amount *= HEAL_DOWN_MULTIPLIER
		detail += "\n\n%s 處於降治療狀態,治療量打 ×%.2f 折扣" % [target.name, HEAL_DOWN_MULTIPLIER]

	var heal_points: int = roundi(effective_amount)
	target.character.heal(heal_points)

	target.battle.log_event(HealEvent.new(target, heal_points, target.hp, detail))
