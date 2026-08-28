class_name WarCampaignController
extends RefCounted

## 玩家點「投入戰場」後,最多連續打 10 場個人戰鬥——每一場都要先問玩家「坐鎮指揮(模擬)
## 還是親臨戰場(即時戰鬥)」,見 System/event/map/war_battle_event.gd 逐場呼叫 AskBattle
## 並在結果 callback 呼叫這裡的 apply_contribution()。連續作戰的前提是連勝:只要有一場
## 沒贏(輸或平手)就在那一場結束,不會再往下打(需求:連續戰鬥 10 場的前提是要連勝)。這個
## 戰場在被結算之前,玩家可以無限次重複投入,每次都是全新的一輪連續作戰,呼叫端自己從 1
## 重新算 streak_count。
##
## 整個流程橫跨多次場景切換(Dialogue ↔ Battle)是非同步的,不能像過去那樣寫成一次跑完的
## 同步迴圈,所以這裡不再持有「跑一整輪」的入口,只留單場結果的共用計算給呼叫端逐場呼叫。

const BATTLE_COUNT := 10


## `streak_count` 是這一輪連續作戰內的第幾場(第 1 場=1,第 2 場=2……),見
## WarContributionRule.war_contribution_for() 的戰功公式。戰功只累加進
## war.player_war_contribution,不在這裡即時發好感度/金錢——換算成實際獎勵延後到整場
## War 停戰、支援國家獲勝時才一次結算,見 NationRelationStore.resolve_truce()。
static func apply_contribution(
	war: War, battle: WarBattle, result: int, supported_is_a: bool, streak_count: int
) -> void:
	var progress_nudge := WarContributionRule.progress_nudge_for(result, supported_is_a)
	battle.battle_progress = clampf(battle.battle_progress + progress_nudge, -100.0, 100.0)
	var power_nudge := WarContributionRule.power_nudge_for(result)
	if supported_is_a:
		battle.battle_power_a += power_nudge
	else:
		battle.battle_power_b += power_nudge

	war.player_war_contribution += WarContributionRule.war_contribution_for(result, battle.rank_type, streak_count)


## 這一輪連續作戰結束(打到輸/平手,或連滿 BATTLE_COUNT 場)時呼叫一次:達到戰場結算門檻
## 就結算「這個戰場」(從 war.active_battles 移除、標記 ENDED),War 本身不受影響繼續進行
## ——War 只透過停戰機率判定結束(見 WarWorldTimeEvents._run_truce_checks()),戰場結算後
## WarBattleSpawner 照樣會在額度內持續補新戰場。
static func settle_battle_if_ready(war: War, battle: WarBattle) -> void:
	if absf(battle.battle_progress) >= WarBattleSimulation.SETTLEMENT_PROGRESS_THRESHOLD \
			or battle.duration_months >= battle.max_duration_months:
		NationRelationStore.settle_battle(war, battle, BattleResultGrader.grade(battle))
