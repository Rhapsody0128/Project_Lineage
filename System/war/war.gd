class_name War
extends RefCounted

## 國家層級的一整場戰爭紀錄。battle_power_a/b 是宣戰當下定值的國力基準,不會被玩家
## 個別戰場的戰鬥貢獻改動——玩家能左右的是 WarBattle 自己的即時 battle_power(見
## war_battle.gd),兩層數值分開才能結構性保證「玩家介入不直接改變全國兵力」。
##
## 不分「戰爭規模」,強弱完全由各自的 WarBattle.rank_type 決定(見
## System/war/war_battle_rank_rule.gd)——War 本身只是「這兩國正在打仗」這件事的容器。

## 玩家尚未表態要幫哪一國。
const SIDE_UNDECIDED := -1
## 玩家已明確決定這整場戰爭都不插手。
const SIDE_NOT_PARTICIPATING := -2

var war_id: String
var attacker: int   # GameEnums.BloodlineNation
var defender: int
var started_date: String
var war_exhaustion_a: float = 0.0
var war_exhaustion_b: float = 0.0
var battle_power_a: float = 0.0
var battle_power_b: float = 0.0
var status: int = GameEnums.WarStatus.ACTIVE
## 同一場戰爭最多同時存在 WarBattleSpawner.MAX_CONCURRENT_BATTLES 個戰場,見
## war_battle_spawner.gd/war_world_time_events.gd。
var active_battles: Array[WarBattle] = []
## 下一次「補新戰場」要等到哪一天(WorldTime day_count)才會生成,-1 代表沒有排定中的
## 下一次生成。跟結算脫鉤——戰場結算與否不影響這個排程,只要還沒到
## MAX_CONCURRENT_BATTLES 上限就會持續補新戰場進來,見 WarBattleSpawner.spawn_battle()。
var next_battle_spawn_day: int = -1
## 玩家在這整場戰爭選邊的結果(SIDE_UNDECIDED/SIDE_NOT_PARTICIPATING 或
## GameEnums.BloodlineNation id)——整場戰爭只鎖一次,不是掛在單一 WarBattle 上,見
## System/event/map/war_battle_event.gd。
var player_side: int = SIDE_UNDECIDED
## 玩家對這場戰爭的戰功,只反映這場 War 期間的貢獻,War 結束(停戰)時歸零,見
## NationRelationStore.resolve_truce()。
var player_war_contribution: int = 0


func other_nation(nation_id: int) -> int:
	return defender if nation_id == attacker else attacker


func exhaustion_for(nation_id: int) -> float:
	return war_exhaustion_a if nation_id == attacker else war_exhaustion_b
