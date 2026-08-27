class_name MoraleRule
extends RefCounted

## 士氣數值(0~100 連續值,存在 MoraleStore.value)換算成「等級」跟「效果」的純規則,
## 不持有任何狀態——跟 AgingRule/BattleReward 同一種「靜態方法集中管理」寫法,方便
## Balance 時只改這裡的表,不用動任何呼叫端(MoraleStore/BattleAi/BattleCharacter/
## Scenes/Map/map.gd/HeaderBar)。
##
## 五個門檻由高到低對齊 CLAUDE.md「一、士氣數值」的建議區間(80/60/40/20/0),
## _tier_index() 回傳 0(極高)~4(崩潰),下面每張表都跟這個索引對齊。

const TIER_THRESHOLDS: Array[float] = [80.0, 60.0, 40.0, 20.0, 0.0]
const TIER_LABELS: Array[String] = ["極高", "高", "普通", "低", "崩潰"]

## 戰鬥素質/大地圖移動速度刻意共用同一套百分比(CLAUDE.md「六、士氣效果」建議表兩者
## 數值相同),之後要分開調整直接拆成兩張表,呼叫端不用跟著改。
const TIER_STAT_MULTIPLIERS: Array[float] = [0.10, 0.05, 0.0, -0.05, -0.10]

## BattleAi 情境權重的士氣乘數:只調整既有候選權重的「比例」,最終仍交給既有的加權
## 隨機骰選(System/battle/battle_ai.gd),不會讓士氣直接決定「一定攻擊」或「一定
## 撤退」,見 CLAUDE.md「七、與 BattleAi 整合」。
const TIER_ATTACK_WEIGHT_MULTIPLIERS: Array[float] = [1.3, 1.15, 1.0, 0.85, 0.7]
const TIER_ESCAPE_WEIGHT_MULTIPLIERS: Array[float] = [0.5, 0.75, 1.0, 1.4, 1.8]
const TIER_DAZE_WEIGHT_MULTIPLIERS: Array[float] = [0.5, 0.75, 1.0, 1.3, 1.6]


static func _tier_index(value: float) -> int:
	for i in TIER_THRESHOLDS.size():
		if value >= TIER_THRESHOLDS[i]:
			return i
	return TIER_THRESHOLDS.size() - 1


static func tier_label(value: float) -> String:
	return TIER_LABELS[_tier_index(value)]


static func combat_stat_multiplier(value: float) -> float:
	return TIER_STAT_MULTIPLIERS[_tier_index(value)]


static func map_move_speed_multiplier(value: float) -> float:
	return TIER_STAT_MULTIPLIERS[_tier_index(value)]


static func ai_attack_weight_multiplier(value: float) -> float:
	return TIER_ATTACK_WEIGHT_MULTIPLIERS[_tier_index(value)]


static func ai_escape_weight_multiplier(value: float) -> float:
	return TIER_ESCAPE_WEIGHT_MULTIPLIERS[_tier_index(value)]


static func ai_daze_weight_multiplier(value: float) -> float:
	return TIER_DAZE_WEIGHT_MULTIPLIERS[_tier_index(value)]


static func ai_tendency_label(value: float) -> String:
	var idx := _tier_index(value)
	if idx <= 1:
		return "積極"
	if idx == 2:
		return "持平"
	return "保守"


static func escape_tendency_label(value: float) -> String:
	var idx := _tier_index(value)
	if idx <= 1:
		return "降低"
	if idx == 2:
		return "正常"
	return "提高"


## Header tooltip「目前效果」區塊用,固定順序:大地圖移動速度/戰鬥素質/戰鬥 AI 傾向/
## 撤退傾向,對齊 CLAUDE.md「二、HEADER 顯示」的 tooltip 版型。
static func effect_description_lines(value: float) -> Array[String]:
	var lines: Array[String] = []
	lines.append("大地圖移動速度：%s" % _format_percent(map_move_speed_multiplier(value)))
	lines.append("戰鬥素質：%s" % _format_percent(combat_stat_multiplier(value)))
	lines.append("戰鬥 AI 傾向：%s" % ai_tendency_label(value))
	lines.append("撤退傾向：%s" % escape_tendency_label(value))
	return lines


static func _format_percent(multiplier: float) -> String:
	if is_equal_approx(multiplier, 0.0):
		return "無影響"
	return "%+d%%" % roundi(multiplier * 100.0)
