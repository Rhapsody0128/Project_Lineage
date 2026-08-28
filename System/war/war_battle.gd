class_name WarBattle
extends RefCounted

## 地圖上的戰場物件——單一 War 目前進行中的其中一個戰鬥模擬實例(同一場 War 最多同時
## MAX_CONCURRENT_BATTLES 個)。命名刻意避開 System/battle/battle.gd 的 Battle(單場戰鬥
## 模擬),兩者不是同一種東西。
##
## battle_power_a/b 是這場戰場自己的、會逐月漂移並吸收玩家戰鬥貢獻的即時值,生成時由
## War.battle_power_a/b(國家基準)乘上 rank_type 對應的係數帶入(見
## war_battle_spawner.gd/war_battle_rank_rule.gd),之後兩者各自獨立變化,不會互相同步。

var battle_id: String
var war_id: String
var position: Vector2
var nation_a: int
var nation_b: int
var battle_power_a: float
var battle_power_b: float
## -100..+100,正值 = nation_a 優勢,負值 = nation_b 優勢,0 = 僵持。
var battle_progress: float = 0.0
var duration_months: int = 0
var status: int = GameEnums.WarBattleStatus.ACTIVE
## 這個戰場自己的難度等級(GameEnums.RankType,F~SSS),生成時均勻隨機骰出,見
## WarBattleRankRule.pick_random_rank()——決定玩家挑戰的敵方 Party 強度、初始戰力乘數、
## 結算前最長月數,不再依附戰爭規模(已移除)。
var rank_type: int
## 結算前最長月數,生成當下依 rank_type 查表定值,見 WarBattleRankRule.max_duration_months()。
var max_duration_months: int
