class_name WarContributionRule
extends RefCounted

## 玩家自己那場個人戰鬥的結果 → 對這個 WarBattle 的影響(battle_progress/battle_power)
## → 戰功,全部集中在這裡,見 WarCampaignController.apply_contribution() 呼叫。戰功
## 只是累加分數,真正換算成金錢/好感度延後到整場 War 停戰、支援國家獲勝時才一次結算
## (見 NationRelationStore.resolve_truce()),不是打完每一場個人戰鬥就即時發放。

const PROGRESS_NUDGE_WIN := 6.0
const PROGRESS_NUDGE_DRAW := 1.0
const POWER_NUDGE_WIN := 25.0
const POWER_NUDGE_DRAW := 5.0

## 戰功 → NationFavorStore 好感度/BaseResourceStore 金錢增量的唯一換算入口,只在
## resolve_truce() 呼叫一次,不要各自 hardcode 一次。先用預留位置數值,之後依遊戲數值
## 調整這兩個常數即可,不用動呼叫端。
const FAVOR_PER_CONTRIBUTION := 0.5
const MONEY_PER_CONTRIBUTION := 15.0


## 玩家個人戰鬥結果轉成對這場 WarBattle 的 battle_progress 位移——只影響這場戰場,
## 不碰 War.battle_power_a/b(國家總戰力),見 spec「玩家介入不直接增加整個國家兵力」。
## 正值往 supported_side_is_a 那一方推。
static func progress_nudge_for(result: int, supported_side_is_a: bool) -> float:
	var magnitude := _magnitude_for_result(result, PROGRESS_NUDGE_WIN, PROGRESS_NUDGE_DRAW)
	return magnitude if supported_side_is_a else -magnitude


static func power_nudge_for(result: int) -> float:
	return _magnitude_for_result(result, POWER_NUDGE_WIN, POWER_NUDGE_DRAW)


static func _magnitude_for_result(result: int, win_amount: float, draw_amount: float) -> float:
	match result:
		GameEnums.BattleResultType.SELF_WIN:
			return win_amount
		GameEnums.BattleResultType.DRAW:
			return draw_amount
		_:
			return 0.0


## 玩家個人戰鬥表現 → war_contribution 分數,獨立於這場 WarBattle 最終誰贏
## (spec:即使支援方最終戰敗,玩家仍可取得戰功)。只有贏才有戰功——連續作戰打到輸/平手
## 的那一場算 0 分,整輪也就此停止(見 System/event/map/war_battle_event.gd 的
## _on_campaign_battle_result()),呼應
## 「連戰連勝很難」的設計初衷。RANK 越高基礎戰功越多、同一輪連勝越久戰功也越多:
## `streak_count` 是這一輪連續作戰內的第幾場(第 1 場=1,第 2 場=2……,每次玩家重新
## 投入同一戰場都是全新一輪、從 1 重算,不跨輪/跨戰爭累積)。公式是「RANK 基礎值
## (rank_type+1)+(streak_count-1)」,化簡後就是 rank_type+streak_count,例如 F 級
## (rank_type=0)第 1/2/3 場連勝分別是 1/2/3 分,E 級(rank_type=1)第 1/2 場連勝分別
## 是 2/3 分。
static func war_contribution_for(result: int, rank_type: int, streak_count: int) -> int:
	if result != GameEnums.BattleResultType.SELF_WIN:
		return 0
	return rank_type + streak_count


static func favor_for_contribution(contribution: int) -> int:
	return maxi(0, roundi(contribution * FAVOR_PER_CONTRIBUTION))


static func money_for_contribution(contribution: int) -> int:
	return maxi(0, roundi(contribution * MONEY_PER_CONTRIBUTION))
