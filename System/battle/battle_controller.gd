class_name BattleController
extends RefCounted

static func get_random_battle() -> Battle:
	var self_party := PartyController.get_random_party()
	var enemy_party := PartyController.get_random_party()
	return Battle.new(self_party, enemy_party)

## PartyEdit「以現在編成開始戰鬥」用:玩家自己編好的小隊對上一個隨機敵方小隊。
static func get_battle_with_self_party(self_party: Party) -> Battle:
	var enemy_party := PartyController.get_random_party()
	return Battle.new(self_party, enemy_party)

## 產生一份戰報:快速跑完一整場隨機戰鬥模擬(不進場景播放),把結果包成
## BattleReport 存進戰報列表。戰報本身只是「已經跑完的 Battle」,重播時
## 直接重放 battle_log,不會重新模擬。
static func generate_random_report(title: String) -> BattleReport:
	var battle := get_random_battle()
	battle.start()
	return BattleReport.new(title, battle)
