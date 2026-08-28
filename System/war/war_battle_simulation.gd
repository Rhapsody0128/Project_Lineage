class_name WarBattleSimulation
extends RefCounted

## 玩家不參戰時,WarBattle 每月的 AI 自動演化——見 war_world_time_events.gd
## monthly_tick() 逐場呼叫 advance_month()。

const BASE_DRIFT_PCT := 0.06
const DRIFT_RANDOMNESS := 0.03
## 領先方(battle_progress 對其有利的一方)每月戰力損耗打的折扣,讓優勢方越打越穩,
## 而不是雙方等速消耗到同時歸零。
const WINNING_SIDE_LOSS_DISCOUNT := 0.4
const SETTLEMENT_PROGRESS_THRESHOLD := 60.0


## 回傳 null 代表這個月還沒分出勝負,繼續打;非 null 代表這個月結算,呼叫端要交給
## NationRelationStore.settle_battle() 處理。戰場拖太久(雙方戰力互相消磨到接近僵持卻
## 遲遲分不出勝負)強制結算,門檻讀 battle.max_duration_months(依戰場自己的 rank_type
## 查表定值,見 WarBattleRankRule),不是全部戰場共用同一個常數。
static func advance_month(battle: WarBattle) -> BattleResult:
	var a_is_leading := battle.battle_progress >= 0.0
	battle.battle_power_a = maxf(0.0, battle.battle_power_a * (1.0 - _drift(a_is_leading)))
	battle.battle_power_b = maxf(0.0, battle.battle_power_b * (1.0 - _drift(not a_is_leading)))
	battle.battle_progress = clampf(_progress_from_power(battle), -100.0, 100.0)
	battle.duration_months += 1

	if absf(battle.battle_progress) >= SETTLEMENT_PROGRESS_THRESHOLD or battle.duration_months >= battle.max_duration_months:
		return BattleResultGrader.grade(battle)
	return null


static func _drift(is_leading: bool) -> float:
	var amount := BASE_DRIFT_PCT + Util.get_random_float(-DRIFT_RANDOMNESS, DRIFT_RANDOMNESS)
	if is_leading:
		amount *= (1.0 - WINNING_SIDE_LOSS_DISCOUNT)
	return maxf(0.0, amount)


static func _progress_from_power(battle: WarBattle) -> float:
	var total := battle.battle_power_a + battle.battle_power_b
	if total <= 0.0:
		return 0.0
	return ((battle.battle_power_a - battle.battle_power_b) / total) * 100.0
