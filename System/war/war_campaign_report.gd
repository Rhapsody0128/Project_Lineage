class_name WarCampaignReport
extends RefCounted

## 玩家投入一個 WarBattle 最多連續打 10 場個人戰鬥(每場都先問 AskBattle,見
## System/event/map/war_battle_event.gd 的 _ask_next_campaign_battle())的結果集合——
## 每一場都是完整的 BattleReport(含 battle_log,可以重播/看統計),這裡只是把整輪包成一組,
## 供戰報列表的「戰爭戰報」分類使用。

var id: String
var war_id: String
var battle_id: String
var supported_nation: int
var enemy_nation: int
var fight_reports: Array[BattleReport] = []
## 戰報列表「描述」欄用的文案,不是時間——比照 BattleReport.description 的欄位定位,
## 戰報列表畫面不要再把這個塞進時間欄顯示。
var title: String
## 投入這場連續作戰當下的遊戲曆法時間(戰報列表「時間」欄用),跟 system_time_text
## (玩家實際操作的現實時刻)分開兩欄,比照 BattleReport.title/system_time_text 的分工。
var game_time_text: String
## 生成戰報當下的現實系統時間,顯示格式跟 BattleReport.system_time_text 一致——這裡直接
## 複製那 3 行格式化邏輯,不特地拉一個共用函式(兩處都很小,抽象化不值得)。
var system_time_text: String


func _init(p_war_id: String, p_battle_id: String, p_supported_nation: int, p_enemy_nation: int,
		p_fight_reports: Array[BattleReport]) -> void:
	id = Util.generate_uuid()
	war_id = p_war_id
	battle_id = p_battle_id
	supported_nation = p_supported_nation
	enemy_nation = p_enemy_nation
	fight_reports = p_fight_reports
	title = title_for(supported_nation, enemy_nation)
	game_time_text = WorldTimeStore.get_display_string()
	var dt := Time.get_datetime_dict_from_system()
	system_time_text = "%04d/%02d/%02d %02d:%02d:%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second]


## 獨立成靜態函式,讓 WarBattleEvent 逐場作戰時也能組出跟這裡一致的文字當每一場的
## description(例如「豹 VS 鷹 戰場戰報-1」「豹 VS 鷹 戰場戰報-2」),不用各自重複拼一次
## 字串導致兩邊格式兜不起來。
static func title_for(p_supported_nation: int, p_enemy_nation: int) -> String:
	return "%s VS %s 戰場戰報" % [
		GameEnums.bloodline_nation_label(p_supported_nation), GameEnums.bloodline_nation_label(p_enemy_nation),
	]


var win_count: int:
	get: return fight_reports.filter(func(r: BattleReport) -> bool: return r.result == GameEnums.BattleResultType.SELF_WIN).size()

var draw_count: int:
	get: return fight_reports.filter(func(r: BattleReport) -> bool: return r.result == GameEnums.BattleResultType.DRAW).size()

var lose_count: int:
	get: return fight_reports.filter(func(r: BattleReport) -> bool: return r.result == GameEnums.BattleResultType.ENEMY_WIN).size()

## 戰績摘要文字,戰報列表/戰爭戰報畫面共用,不各自拼一次。
var result_summary_text: String:
	get: return "%d 勝 %d 平 %d 敗" % [win_count, draw_count, lose_count]

## 10 場之中最長的連勝紀錄(不是「目前」連勝,是掃過整份清單找最長的一段)。
var best_win_streak: int:
	get:
		var best := 0
		var current := 0
		for report in fight_reports:
			if report.result == GameEnums.BattleResultType.SELF_WIN:
				current += 1
				best = maxi(best, current)
			else:
				current = 0
		return best
