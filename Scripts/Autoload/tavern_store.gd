extends Node

# =========================================================
# 酒館(Scenes/MapLocation「酒館」按鈕觸發 TownTavernEvent)的每月固定內容,兩塊各自
# 「這個月只骰/生成一次,重複進出酒館都看到同一份結果」:
#   - 老闆介紹的可招募英雄清單(current_recruits,見 get_recruits())。
#   - 異鄉人搭訕事件是否發生、跟誰(has_encounter/encounter_stranger/encounter_courted,
#     見 should_show_encounter())——骰過一次之後同一個月不管進出酒館幾次都是同一個
#     結果,直到 TownTavernEvent 把這次搭訕的告白流程走到底(接受/婉拒/沒人符合資格)
#     才算 resolved,resolved 之後這個月剩下的時間再進酒館只會看到老闆招呼詞,不會重複
#     觸發同一次搭訕。
#
# 跟 BaseExchangeStore 同一套慣例:_ready() 自己註冊 WorldTimeStore 的月事件,不假手
# WorldTimeEventLibrary。
# =========================================================

## 進酒館遇到異鄉人搭訕的機率(百分比),見 should_show_encounter()。
const ENCOUNTER_CHANCE_PERCENT := 30
const RECRUIT_HERO_COUNT := 5

var current_recruits: Array[Character] = []

var has_encounter: bool = false
var encounter_resolved: bool = false
var encounter_stranger: Character = null
var encounter_courted: Character = null
var _encounter_rolled: bool = false


func _ready() -> void:
	WorldTimeStore.controller.register_month_event(_on_month_passed)


func get_recruits() -> Array[Character]:
	if current_recruits.is_empty():
		_generate_recruits()
	return current_recruits


## TownTavernEvent._start() 呼叫:回傳這個月「還有沒有」搭訕事件可以播。骰子只在這個月
## 第一次呼叫時真的丟(_encounter_rolled),之後同一個月不管呼叫幾次都回傳同一個結果——
## 玩家重複進出酒館看到的是同一次搭訕機會,直到走完流程(見 mark_encounter_resolved())
## 才會變成 false。骰中但角色池裡沒有符合資格的對象(encounter_courted 為 null)也視為
## 「有搭訕」,由 TownTavernEvent 自己判斷 encounter_courted 是否為 null 決定要播告白
## 流程還是「認錯人了」的佔位反應句。
func should_show_encounter() -> bool:
	if not _encounter_rolled:
		_encounter_rolled = true
		_roll_encounter()
	return has_encounter and not encounter_resolved


## 這次搭訕的告白流程已經走到終點(接受/婉拒/沒人符合資格),這個月剩下的時間不會再
## 重複觸發——由 TownTavernEvent 在確定終局的當下呼叫。
func mark_encounter_resolved() -> void:
	encounter_resolved = true


func _generate_recruits() -> void:
	current_recruits.clear()
	for i in range(RECRUIT_HERO_COUNT):
		current_recruits.append(CharacterController.get_random_character(GameEnums.RankType.F))


func _roll_encounter() -> void:
	if Util.get_random_float(0.0, 100.0) >= ENCOUNTER_CHANCE_PERCENT:
		return
	has_encounter = true
	encounter_stranger = CharacterController.get_random_character(GameEnums.RankType.F)

	var eligible: Array[Character] = []
	for character in CharacterRosterStore.all_characteres:
		if MarriageRule.can_propose(character, encounter_stranger):
			eligible.append(character)
	if not eligible.is_empty():
		encounter_courted = Util.get_random_from_array(eligible)


func _on_month_passed() -> void:
	_generate_recruits()
	_encounter_rolled = false
	has_encounter = false
	encounter_resolved = false
	encounter_stranger = null
	encounter_courted = null


func to_save_data() -> Dictionary:
	var recruits: Array = []
	for character in current_recruits:
		recruits.append(SaveDataCodec.encode_character(character))

	return {
		"recruits": recruits,
		"encounter_rolled": _encounter_rolled,
		"has_encounter": has_encounter,
		"encounter_resolved": encounter_resolved,
		"encounter_stranger": SaveDataCodec.encode_character(encounter_stranger) if encounter_stranger != null else {},
		"encounter_courted_id": encounter_courted.id if encounter_courted != null else "",
	}


## by_id 是 AllCharacterStore.load_save_data() 回傳的 id → Character 對照表(見
## save_load_store.gd 的讀檔順序),encounter_courted 是玩家角色池裡的既有角色,只存 id、
## 靠這份對照表換回實際參照——跟 encounter_stranger(尚未屬於任何角色池的一次性 NPC,
## 要整份重新解碼,見 recruits 同一套存法)不是同一種存法。recruits 清單裡「已經被招募」
## 的候補英雄也要換成 by_id 裡的既有參照,不能整份重新解碼出另一個同 id 但不同物件實體
## 的 Character——TownTavernEvent._build_recruit_item() 判斷「已招募」是拿
## CharacterRosterStore.all_characteres.has(hero) 比物件參照,不是比 id,解碼出來的複本
## 永遠對不上,會讓讀檔後已招募過的按鈕又變回可以按。
func load_save_data(data: Dictionary, by_id: Dictionary) -> void:
	current_recruits.clear()
	for entry in data.get("recruits", []):
		var character_id: String = entry.get("id", "")
		if by_id.has(character_id):
			current_recruits.append(by_id[character_id])
		else:
			current_recruits.append(SaveDataCodec.decode_character_base(entry))

	_encounter_rolled = data.get("encounter_rolled", false)
	has_encounter = data.get("has_encounter", false)
	encounter_resolved = data.get("encounter_resolved", false)

	var stranger_data: Dictionary = data.get("encounter_stranger", {})
	encounter_stranger = SaveDataCodec.decode_character_base(stranger_data) if not stranger_data.is_empty() else null

	var courted_id: String = data.get("encounter_courted_id", "")
	encounter_courted = by_id.get(courted_id, null) if courted_id != "" else null
