class_name WarBattleSpawner
extends RefCounted

## 同一場戰爭最多同時存在幾個戰場,固定值,不因 RANK 或其他因素變動——地圖上一次最多看到
## 這麼多個屬於同一場戰爭的 ⚔ 圖示。
const MAX_CONCURRENT_BATTLES := 4
## 額度未滿時,補下一個新戰場要間隔幾個月——跟戰場結算脫鉤(見 war.gd 的
## next_battle_spawn_day 註解),戰場結算與否不影響這個排程。
const NEXT_BATTLE_SPAWN_DELAY_MONTHS := 1


## 無條件生成一個新戰場、加進 war.active_battles,並重新排定下一次補新戰場的天數——呼叫端
## (宣戰/月結生成檢查)要自己先確認還沒到 MAX_CONCURRENT_BATTLES 上限才呼叫這裡。
static func spawn_battle(war: War) -> WarBattle:
	var battle := WarBattle.new()
	battle.battle_id = Util.generate_uuid()
	battle.war_id = war.war_id
	battle.position = WarBattlePositionPicker.pick_position(war.attacker, war.defender)
	battle.nation_a = war.attacker
	battle.nation_b = war.defender
	battle.rank_type = WarBattleRankRule.pick_random_rank()
	battle.max_duration_months = WarBattleRankRule.max_duration_months(battle.rank_type)

	var multiplier := WarBattleRankRule.initial_power_multiplier(battle.rank_type)
	battle.battle_power_a = war.battle_power_a * multiplier
	battle.battle_power_b = war.battle_power_b * multiplier

	war.active_battles.append(battle)
	var current_day := WorldTimeStore.controller.world_time.get_day_count()
	war.next_battle_spawn_day = current_day + NEXT_BATTLE_SPAWN_DELAY_MONTHS * WorldTime.DAYS_PER_MONTH
	return battle
