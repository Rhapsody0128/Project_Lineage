class_name BattleReport
extends RefCounted

## 戰報:包裝一場「已經跑完模擬」的 Battle(含固定內容的 battle_log),
## 供戰報列表儲存/重複播放。播放本身不重新模擬,只重播 battle 裡已經記錄好的
## battle_log,所以同一份戰報第一次跟第二次播放,招式與扣血量必定完全相同。

var id: String
var title: String
var battle: Battle

func _init(p_title: String, p_battle: Battle) -> void:
	id = Util.generate_uuid()
	title = p_title
	battle = p_battle

## 結算結果直接讀 battle_log 裡的 battle_end 事件,不用 battle.self_total_hp /
## enemy_total_hp 現算——那兩個 getter 讀的是角色目前 HP,重播前會被
## Battle.reset_for_replay() 還原成開戰時的滿血,不能拿來當結算數字。
var self_total_hp: int:
	get: return _result_totals().self_total
var enemy_total_hp: int:
	get: return _result_totals().enemy_total

## GameEnums.BattleResultType:只看雙方總大將死活,不比較 HP——供需要依勝負分色/分支的
## 呼叫端使用(例如戰報列表),不要自己另外比較 self_total_hp/enemy_total_hp。
var result: int:
	get: return _result_totals().result

var result_text: String:
	get:
		match result:
			GameEnums.BattleResultType.SELF_WIN:
				return "我方勝利"
			GameEnums.BattleResultType.ENEMY_WIN:
				return "敵方勝利"
			_:
				return "平手"

func _result_totals() -> Dictionary:
	for event in battle.battle_log:
		if event.type == "battle_end":
			return {"self_total": event.self_total, "enemy_total": event.enemy_total, "result": event.result}
	return {"self_total": 0, "enemy_total": 0, "result": GameEnums.BattleResultType.DRAW}
