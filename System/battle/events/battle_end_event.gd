class_name BattleEndEvent
extends BattleEvent

## 整場戰鬥的收尾標記,見 Battle._conclude_battle()。self_total/enemy_total 是雙方隊伍
## 結束當下的總 HP——只給畫面展示用(例如結果 Dialog 秀「我方總血量 vs 敵方總血量」),
## 不影響 result 本身的判定:勝負一律看雙方隊長死活(Battle.result),不比較 HP 高低,
## 見該欄位註解。

var round: int
var self_total: int
var enemy_total: int
var result: GameEnums.BattleResultType

func _init(p_round: int, p_self_total: int, p_enemy_total: int, p_result: GameEnums.BattleResultType) -> void:
	super._init(GameEnums.BattleEventType.BATTLE_END)
	round = p_round
	self_total = p_self_total
	enemy_total = p_enemy_total
	result = p_result
