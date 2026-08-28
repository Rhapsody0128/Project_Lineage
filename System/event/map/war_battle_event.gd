class_name WarBattleEvent
extends LocationEvent

## 大地圖走到 WarBattle(地圖上的戰場物件)觸發的流程——整套走 Dialogue(見
## System/dialogue/ + Scenes/Dialogue/dialogue_box.gd),不疊加 ActionPanel:選邊/戰場
## 選項/見指揮官/連續作戰結果全部是切場景的對話,播完由 DialogueChoice 或
## goto_dialogue() 的 on_finished 接手下一段或回地圖,比照
## System/event/map/roaming_enemy_event.gd 的寫法。
##
## 選邊敘事只在 war.player_side == War.SIDE_UNDECIDED 時觸發:選支援某一國會呼叫
## NationRelationStore.set_player_side() 永久鎖定這整場戰爭;選「不插手」則刻意不呼叫
## set_player_side()、player_side 維持 SIDE_UNDECIDED——不插手只是這次暫時不插手,不代表
## 這整場戰爭都不插手,下次在這場戰爭遇到任何戰場都會重新問一次。
##
## 戰場選項畫面(玩家已經選邊,不管是剛選完還是之前選過)固定三個選項:見指揮官(一段
## 風味對話後回到同一個選項畫面,不會真的離開)、投入戰場(連續作戰,見
## System/war/war_campaign_controller.gd)、離開。PartyStore.party 還沒編組時不列
## 「投入戰場」,比照 RoamingEnemyEvent 的 has_party 分支。
##
## 疲憊度/戰功/戰鬥值/戰局佔優這些戰爭內部數值刻意不在對話文字裡秀出來給玩家看(只在
## Scenes/NationRelations 那種專門的數值畫面才顯示)——戰場選項對話/見指揮官對話都只留
## 最精簡的一句話,見 _build_battlefield_dialogue()/_build_commander_dialogue()。
##
## 投入戰場是連續最多 10 場個人戰鬥,但不是背景一次跑完——每一場都要先問玩家「坐鎮指揮
## (模擬)還是親臨戰場(即時戰鬥)」,見 _ask_next_campaign_battle() 呼叫 AskBattle.ask()。
## 贏了播一句連勝台詞接著問下一場;輸了/平手播對應台詞,連續作戰就此中斷,見
## _on_campaign_battle_result()。每一場的 BattleReport 靠 AskBattle.ask() 的
## record_in_report_list=false/report_description 兩個加碼參數控制:不寫進戰報列表的
## 「一般戰鬥」清單(只掛在「戰爭戰報」分類底下,見 _finish_campaign()),描述文字用
## 「豹 VS 鷹 戰場戰報-1」這種格式(WarCampaignReport.title_for() 加上第幾場),不是
## 預設的「O級敵人遭遇戰」。

const RETURN_SCENE_PATH := "res://Scenes/Map/map.tscn"
const BATTLE_SCENE_PATH := "res://Scenes/Battle/battle.tscn"

var _battle: WarBattle

## 以下三個只在「投入戰場」互動流程進行中才有意義,見 _on_join_campaign() 起始化。
var _campaign_war: War
var _campaign_battle_number: int = 0
var _campaign_fight_reports: Array[BattleReport] = []


func _init(p_battle: WarBattle) -> void:
	_battle = p_battle


static func trigger(battle: WarBattle) -> void:
	var event := WarBattleEvent.new(battle)
	event._start()


func _start() -> void:
	var war := NationRelationStore.find_war(_battle.war_id)
	if war.player_side == War.SIDE_UNDECIDED:
		goto_dialogue(_build_intro_dialogue(war), RETURN_SCENE_PATH)
	else:
		goto_dialogue(_build_battlefield_dialogue(war), RETURN_SCENE_PATH)


## 「看起來 O 國跟 X 國發生了衝突,你決定——」三選一:支援攻方/支援守方/不插手。
func _build_intro_dialogue(war: War) -> Dialogue:
	var narrator := DialogueSpeaker.new("narrator", "", "", GameEnums.DialogueSide.NARRATOR)
	var leader := LeaderStore.get_leader()
	var leader_speaker := DialogueSpeaker.new(leader.id, leader.full_name, leader.face_path, GameEnums.DialogueSide.LEFT)

	var choices: Array[DialogueChoice] = [
		DialogueChoice.new("支援 %s" % GameEnums.bloodline_nation_label(war.attacker), "", func(): _on_side_chosen(war, war.attacker)),
		DialogueChoice.new("支援 %s" % GameEnums.bloodline_nation_label(war.defender), "", func(): _on_side_chosen(war, war.defender)),
		DialogueChoice.new("不插手", "", func(): _on_decline_chosen(war)),
	]

	var lines: Array[DialogueLine] = [
		DialogueLine.new(narrator.id, "看起來 %s 跟 %s 發生了衝突。" % [
			GameEnums.bloodline_nation_label(war.attacker), GameEnums.bloodline_nation_label(war.defender),
		]),
		DialogueLine.new(leader_speaker.id, "你決定——", choices),
	]
	return Dialogue.new([narrator, leader_speaker], lines, _background_path(war))


## 選了支援某一國:永久鎖定這整場戰爭的 player_side,接著直接進戰場選項畫面。
func _on_side_chosen(war: War, side: int) -> void:
	NationRelationStore.set_player_side(war, side)
	goto_dialogue(_build_battlefield_dialogue(war), RETURN_SCENE_PATH)


## 選了不插手:不動 player_side(維持 SIDE_UNDECIDED),播一句收尾台詞後回地圖——下次
## 遇到這場戰爭的任何戰場都會重新問一次選邊敘事。
func _on_decline_chosen(war: War) -> void:
	goto_dialogue(_build_decline_dialogue(war), RETURN_SCENE_PATH)


func _build_decline_dialogue(war: War) -> Dialogue:
	var leader := LeaderStore.get_leader()
	var leader_speaker := DialogueSpeaker.new(leader.id, leader.full_name, leader.face_path, GameEnums.DialogueSide.LEFT)
	var lines: Array[DialogueLine] = [
		DialogueLine.new(leader_speaker.id, "（先觀察情勢,這次暫時不插手。）"),
	]
	return Dialogue.new([leader_speaker], lines, _background_path(war))


## 戰場選項畫面:精簡成一句「看起來是 %s 級的戰場,你決定——」接三個選項,不再另外秀
## VS 對戰國/戰局佔優/支援對象這些前情提要,見檔頭註解。
func _build_battlefield_dialogue(war: War) -> Dialogue:
	var narrator := DialogueSpeaker.new("narrator", "", "", GameEnums.DialogueSide.NARRATOR)
	var leader := LeaderStore.get_leader()
	var leader_speaker := DialogueSpeaker.new(leader.id, leader.full_name, leader.face_path, GameEnums.DialogueSide.LEFT)

	var lines: Array[DialogueLine] = []

	var has_party := PartyStore.party != null
	if not has_party:
		lines.append(DialogueLine.new(narrator.id, "(尚未編組隊伍,暫時無法投入戰場。)"))

	var choices: Array[DialogueChoice] = [
		DialogueChoice.new("見 %s 指揮官" % GameEnums.bloodline_nation_label(war.player_side), "", func(): _on_meet_commander(war)),
	]
	if has_party:
		choices.append(DialogueChoice.new("投入戰場(連續作戰)", "", func(): _on_join_campaign(war)))
	choices.append(DialogueChoice.new("離開", RETURN_SCENE_PATH))

	lines.append(DialogueLine.new(leader_speaker.id, "看起來是 %s 級的戰場,你決定——" % GameEnums.rank_label(_battle.rank_type), choices))

	return Dialogue.new([narrator, leader_speaker], lines, _background_path(war))


## 見指揮官:一句風味台詞播完,由 on_finished 接手重新打開戰場選項畫面(比照
## System/event/town/town_tavern_event.gd 老闆招呼詞「播完接手開下一段」的慣例),不是真的
## 離開,玩家選完這個選項還能接著選 B/C。
func _on_meet_commander(war: War) -> void:
	goto_dialogue(_build_commander_dialogue(war), "", func(): goto_dialogue(_build_battlefield_dialogue(war), RETURN_SCENE_PATH))


## 只給一句固定的風味台詞,不依疲憊/戰局挑語氣——那些是刻意隱藏的內部數值,不該連間接
## 透過指揮官語氣變化透露給玩家,見檔頭註解。
func _build_commander_dialogue(war: War) -> Dialogue:
	var commander := DialogueSpeaker.new("commander", "%s指揮官" % GameEnums.bloodline_nation_label(war.player_side), "", GameEnums.DialogueSide.RIGHT)
	var lines: Array[DialogueLine] = [DialogueLine.new(commander.id, "辛苦你了,還請你多加把勁。")]
	return Dialogue.new([commander], lines, _background_path(war))


## 投入戰場:啟動這一輪連續作戰(streak 從 1 重算),第一場直接問 AskBattle——不是背景
## 一次跑完,見檔頭註解與 _ask_next_campaign_battle()。
func _on_join_campaign(war: War) -> void:
	_campaign_war = war
	_campaign_battle_number = 0
	_campaign_fight_reports = []
	_ask_next_campaign_battle()


## 生一個隨機敵方 Party 問玩家 AskBattle(坐鎮指揮/親臨戰場),結果一律回到
## _on_campaign_battle_result()。on_report 把這場的完整 BattleReport 收進
## _campaign_fight_reports,供最後包成 WarCampaignReport 用(見 AskBattle.ask() 的
## on_report 加碼欄位)。record_in_report_list 傳 false——這場戰報只掛在「戰爭戰報」
## 分類底下(見 _finish_campaign()),不重複出現在「一般戰鬥」清單;report_description
## 直接沿用 WarCampaignReport.title_for() 加上第幾場,跟父列一致,不是預設的
## 「O級敵人遭遇戰」。
func _ask_next_campaign_battle() -> void:
	_campaign_battle_number += 1
	var enemy_nation := _enemy_nation(_campaign_war)
	var enemy_party := PartyController.get_random_party(_battle.rank_type, enemy_nation)
	var description := "%s-%d" % [
		WarCampaignReport.title_for(_campaign_war.player_side, enemy_nation), _campaign_battle_number,
	]
	AskBattle.ask(
		PartyStore.party, enemy_party,
		BATTLE_SCENE_PATH, RETURN_SCENE_PATH,
		WorldTimeStore.get_display_string(),
		func(result: GameEnums.BattleResultType) -> void: _on_campaign_battle_result(result),
		func(report: BattleReport) -> void: _campaign_fight_reports.append(report),
		false, description, false
	)


## 贏了且還沒打滿 BATTLE_COUNT 場:播連勝台詞,由 on_finished 接手問下一場(留在同一輪連續
## 作戰內,不回地圖)。輸/平手,或連勝打滿 BATTLE_COUNT 場:播對應收尾台詞後結束這一輪。
func _on_campaign_battle_result(result: GameEnums.BattleResultType) -> void:
	var supported_is_a := _campaign_war.player_side == _battle.nation_a
	WarCampaignController.apply_contribution(_campaign_war, _battle, result, supported_is_a, _campaign_battle_number)

	var reached_cap := _campaign_battle_number >= WarCampaignController.BATTLE_COUNT
	var is_win := result == GameEnums.BattleResultType.SELF_WIN
	var progress_dialogue := _build_campaign_progress_dialogue(result, _campaign_battle_number, reached_cap)
	if is_win and not reached_cap:
		goto_dialogue(progress_dialogue, "", func(): _ask_next_campaign_battle())
	else:
		goto_dialogue(progress_dialogue, "", func(): _finish_campaign())


## 只播「連勝/戰敗/平手」的定性台詞,不秀戰功等內部數字(streak 是玩家看得到的連勝場數,
## 不是隱藏的戰功分數,見檔頭註解)。
func _build_campaign_progress_dialogue(result: GameEnums.BattleResultType, streak: int, reached_cap: bool) -> Dialogue:
	var narrator := DialogueSpeaker.new("narrator", "", "", GameEnums.DialogueSide.NARRATOR)
	var text: String
	if result == GameEnums.BattleResultType.SELF_WIN:
		text = "%d 連勝!打滿了這一輪,暫時收兵。" % streak if reached_cap else "%d 連勝!但戰爭還在繼續……" % streak
	elif result == GameEnums.BattleResultType.ENEMY_WIN:
		text = "戰敗了,弟兄們暫時撤退……"
	else:
		text = "打成平手,雙方都退了下來……"
	return Dialogue.new([narrator], [DialogueLine.new(narrator.id, text)], _background_path(_campaign_war))


## 這一輪連續作戰結束(不管是輸/平手中斷,還是連勝打滿):把累積的戰報包成
## WarCampaignReport 存進戰報列表的「戰爭戰報」分類,順便檢查這場戰場是否達到結算門檻
## (見 WarCampaignController.settle_battle_if_ready()),最後播結果總結回地圖。
func _finish_campaign() -> void:
	var war := _campaign_war
	var enemy_nation := _enemy_nation(war)
	var report := WarCampaignReport.new(war.war_id, _battle.battle_id, war.player_side, enemy_nation, _campaign_fight_reports)
	BattleReportStore.add_war_campaign_report(report)
	WarCampaignController.settle_battle_if_ready(war, _battle)
	goto_dialogue(_build_campaign_result_dialogue(war, report), RETURN_SCENE_PATH)


func _enemy_nation(war: War) -> int:
	return _battle.nation_b if war.player_side == _battle.nation_a else _battle.nation_a


func _build_campaign_result_dialogue(war: War, report: WarCampaignReport) -> Dialogue:
	var narrator := DialogueSpeaker.new("narrator", "", "", GameEnums.DialogueSide.NARRATOR)
	var lines: Array[DialogueLine] = [
		DialogueLine.new(narrator.id, "這場戰事你打了 %d 場:%s。" % [report.fight_reports.size(), report.result_summary_text]),
		DialogueLine.new(narrator.id, "(詳細戰報可在戰報列表的「戰爭戰報」分類查看。)"),
	]
	return Dialogue.new([narrator], lines, _background_path(war))


## 對話背景圖優先看戰場座標落在 MapTerrainMask 的哪個國家色塊範圍內,查不到(山岳/海面/
## 地圖外)才 fallback 用攻方國家的地形,比照 RoamingEnemyEvent._background_path() 的
## 既有慣例。
func _background_path(war: War) -> String:
	var nation := MapTerrainMask.nation_at(_battle.position)
	if nation != -1:
		return GameEnums.terrain_background_path(GameEnums.bloodline_nation_terrain(nation))
	return GameEnums.terrain_background_path(GameEnums.bloodline_nation_terrain(war.attacker))
