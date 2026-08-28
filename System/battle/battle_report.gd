class_name BattleReport
extends RefCounted

## 戰報:包裝一場「已經跑完模擬」的 Battle(含固定內容的 battle_log),
## 供戰報列表儲存/重複播放。播放本身不重新模擬,只重播 battle 裡已經記錄好的
## battle_log,所以同一份戰報第一次跟第二次播放,招式與扣血量必定完全相同。

var id: String
var title: String
var battle: Battle
## 生成戰報當下的現實系統時間,顯示格式 "2026/08/16 16:11:31"(戰報列表表格用,跟
## title 的遊戲曆法時間分開兩欄——title 是遊戲世界的 BC 紀年,這個是玩家實際操作的時刻)。
var system_time_text: String
## 戰報列表「描述」欄用的一句話文案。呼叫端不指定就自動依敵方 rank_type 生成
## 「O級敵人遭遇戰」(一般戰鬥的預設情境);呼叫端明確指定時(例如
## WarCampaignController 連續作戰的「第 N 場」)直接採用呼叫端給的文字,不覆蓋。
var description: String

func _init(p_title: String, p_battle: Battle, p_description: String = "") -> void:
	id = Util.generate_uuid()
	title = p_title
	battle = p_battle
	description = p_description if not p_description.is_empty() else _default_description(p_battle)
	system_time_text = _format_system_time()

static func _default_description(p_battle: Battle) -> String:
	return "%s級敵人遭遇戰" % GameEnums.rank_label(p_battle.enemy_rank_type)

static func _format_system_time() -> String:
	var dt := Time.get_datetime_dict_from_system()
	return "%04d/%02d/%02d %02d:%02d:%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second]

## 結算結果直接讀 battle.battle_end_event(型別化,戰鬥跑完後一定有值),不用
## battle.self_total_hp / enemy_total_hp 現算——那兩個 getter 讀的是角色目前 HP,
## 重播前會被 Battle.reset_for_replay() 還原成開戰時的滿血,不能拿來當結算數字。
var self_total_hp: int:
	get: return battle.battle_end_event.self_total
var enemy_total_hp: int:
	get: return battle.battle_end_event.enemy_total

## GameEnums.BattleResultType:只看雙方總大將死活,不比較 HP——供需要依勝負分色/分支的
## 呼叫端使用(例如戰報列表),不要自己另外比較 self_total_hp/enemy_total_hp。
var result: GameEnums.BattleResultType:
	get: return battle.battle_end_event.result

var result_text: String:
	get:
		match result:
			GameEnums.BattleResultType.SELF_WIN:
				return "勝利"
			GameEnums.BattleResultType.ENEMY_WIN:
				return "戰敗"
			_:
				return "平手"
