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

## AskBattle(見 Scenes/BattleUtil/ask_battle.gd)用:雙方小隊都由呼叫端明確指定
## (例如城門守衛挑戰的 enemy_party 是特定生成的一支隊伍),不像
## get_battle_with_self_party() 那樣讓敵方隨機生。
static func get_battle(self_party: Party, enemy_party: Party) -> Battle:
	return Battle.new(self_party, enemy_party)

## 產生一份戰報:快速跑完一整場隨機戰鬥模擬(不進場景播放),把結果包成
## BattleReport 存進戰報列表。戰報本身只是「已經跑完的 Battle」,重播時
## 直接重放 battle_log,不會重新模擬。
static func generate_random_report(title: String) -> BattleReport:
	var battle := get_random_battle()
	battle.start()
	return BattleReport.new(title, battle)

## AskBattle「選是跳過戰鬥」用:雙方小隊都由呼叫端指定,直接把整場戰鬥模擬完
## 包成戰報,不進 Battle 場景播放動畫。
static func generate_report_for_parties(title: String, self_party: Party, enemy_party: Party) -> BattleReport:
	var battle := get_battle(self_party, enemy_party)
	battle.start()
	return BattleReport.new(title, battle)
