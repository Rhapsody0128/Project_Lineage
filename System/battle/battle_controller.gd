class_name BattleController
extends RefCounted

static func get_random_battle() -> Battle:
	var self_party := PartyController.get_random_party(GameEnums.RankType.F)
	var enemy_party := PartyController.get_random_party(GameEnums.RankType.F)
	return Battle.new(self_party, enemy_party)

## PartyEdit「以現在編成開始戰鬥」用:玩家自己編好的小隊對上一個隨機敵方小隊。
static func get_battle_with_self_party(self_party: Party) -> Battle:
	var enemy_party := PartyController.get_random_party(GameEnums.RankType.F)
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
## 包成戰報,不進 Battle 場景播放動畫。這條路徑不會經過 Scenes/Battle/battle.gd 的
## _run_battle_playback()/_run_battle_realtime(),所以勝利 EXP/金錢獎懲要在這裡自己
## 補發一次,否則玩家選「跳過戰鬥」打贏也不會有 EXP/金錢(戰報照樣顯示勝利,容易
## 誤以為是 bug)。grant_nation_favor 預設 true(維持原本行為);戰爭連續作戰
## (WarBattleEvent)傳 false——enemy_party.nation_type 在那裡代表「正在打的敵對國」,
## 跟 grant_victory_favor 原本「敵方是佔地盤盜賊,打贏替失地國家加好感度」的語意相反,
## 見 System/war/war_contribution_rule.gd:戰爭的好感度只在停戰時依戰功一次結算。
static func generate_report_for_parties(
		title: String, self_party: Party, enemy_party: Party, description: String = "",
		grant_nation_favor: bool = true
) -> BattleReport:
	var battle := get_battle(self_party, enemy_party)
	battle.start()
	BattleReward.grant_victory_exp(battle)
	BattleReward.settle_money(battle)
	if grant_nation_favor:
		BattleReward.grant_victory_favor(battle)
	BattleReward.settle_morale(battle)
	return BattleReport.new(title, battle, description)
