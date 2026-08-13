class_name BattleController
extends RefCounted

static func get_random_battle() -> Battle:
	var self_troop := TroopController.get_random_troop()
	var enemy_troop := TroopController.get_random_troop()
	return Battle.new(self_troop, enemy_troop)

## 產生一份戰報:快速跑完一整場隨機戰鬥模擬(不進場景播放),把結果包成
## BattleReport 存進戰報列表。戰報本身只是「已經跑完的 Battle」,重播時
## 直接重放 battle_log,不會重新模擬。
static func generate_random_report(title: String = "隨機戰報") -> BattleReport:
	var battle := get_random_battle()
	battle.start()
	return BattleReport.new(title, battle)
