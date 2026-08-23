extends Node

# =========================================================
# 酒館(Scenes/MapLocation「酒館」按鈕觸發 TownTavernEvent)的每月固定內容,三塊各自
# 「這個月只骰/生成一次,重複進出酒館都看到同一份結果」:
#   - 老闆介紹的可招募英雄清單(current_recruits,見 get_recruits())。
#   - 老闆的「特殊推薦」(special_recruit,見 get_special_recruit()):花錢才能招募的
#     單一高評級人選,見 TownTavernEvent 的頭像塗黑呈現。
#   - 異鄉人搭訕事件是否發生、跟誰(has_encounter/encounter_stranger/encounter_courted,
#     見 should_show_encounter())——骰過一次之後同一個月不管進出酒館幾次都是同一個
#     結果,直到 TownTavernEvent 把這次搭訕的告白流程走到底(接受/婉拒/沒人符合資格)
#     才算 resolved,resolved 之後這個月剩下的時間再進酒館只會看到老闆招呼詞,不會重複
#     觸發同一次搭訕。
#
# 三塊的抽選基礎評級都不是固定 RankType.F,改依呼叫端傳入的 nation(該城鎮所屬國家,見
# TownTavernEvent._nation)在 NationFavorStore 的好感度換算出來(見 _resolve_base_rank()):
# 城鎮所屬國家好感度愈高,酒館能遇到的人才評級基準愈高。special_recruit 是基礎評級再 +1
# (封頂 SSS,見 _special_recruit_rank()/special_recruit_available())。
#
# 跟 BaseExchangeStore 同一套慣例:_ready() 自己註冊 WorldTimeStore 的月事件,不假手
# WorldTimeEventLibrary。
# =========================================================

## 進酒館遇到異鄉人搭訕的機率(百分比),見 should_show_encounter()。
const ENCOUNTER_CHANCE_PERCENT := 100
const RECRUIT_HERO_COUNT := 4

## 特殊推薦(頭像塗黑、只顯示名字/等級)的招募花費,見 TownTavernEvent 的 SPECIAL_RECRUIT
## 相關常數/方法。
const SPECIAL_RECRUIT_COST_GOLD := 300

var current_recruits: Array[Character] = []
var special_recruit: Character = null

var has_encounter: bool = false
var encounter_resolved: bool = false
var encounter_stranger: Character = null
var encounter_courted: Character = null
var _encounter_rolled: bool = false


func _ready() -> void:
	WorldTimeStore.controller.register_month_event(_on_month_passed)


func get_recruits(nation: int = -1) -> Array[Character]:
	if current_recruits.is_empty():
		_generate_recruits(nation)
	return current_recruits


## 這個月的特殊推薦人選(第一次呼叫才真的生成,之後同一個月固定回傳同一個 Character,
## 呼叫慣例跟 get_recruits() 一致)。評級是 _resolve_base_rank(nation) + 1,見
## _special_recruit_rank()。
func get_special_recruit(nation: int = -1) -> Character:
	if special_recruit == null:
		special_recruit = _generate_character(_special_recruit_rank(nation), nation)
	return special_recruit


## 基礎評級已經是最高 SSS 時,+1 沒有更高的評級可以探,呼叫端(TownTavernEvent)用這個
## 決定特殊推薦按鈕要不要一開始就 disabled。
func special_recruit_available(nation: int = -1) -> bool:
	return _resolve_base_rank(nation) < GameEnums.RankType.SSS


## TownTavernEvent._start() 呼叫:回傳這個月「還有沒有」搭訕事件可以播。骰子只在這個月
## 第一次呼叫時真的丟(_encounter_rolled),之後同一個月不管呼叫幾次都回傳同一個結果——
## 玩家重複進出酒館看到的是同一次搭訕機會,直到走完流程(見 mark_encounter_resolved())
## 才會變成 false。骰中但角色池裡沒有符合資格的對象(encounter_courted 為 null)也視為
## 「有搭訕」,由 TownTavernEvent 自己判斷 encounter_courted 是否為 null 決定要播告白
## 流程還是「認錯人了」的佔位反應句。
func should_show_encounter(nation: int = -1) -> bool:
	if not _encounter_rolled:
		_encounter_rolled = true
		_roll_encounter(nation)
	return has_encounter and not encounter_resolved


## 這次搭訕的告白流程已經走到終點(接受/婉拒/沒人符合資格),這個月剩下的時間不會再
## 重複觸發——由 TownTavernEvent 在確定終局的當下呼叫。
func mark_encounter_resolved() -> void:
	encounter_resolved = true


func _generate_recruits(nation: int) -> void:
	current_recruits.clear()
	var base_rank := _resolve_base_rank(nation)
	for i in range(RECRUIT_HERO_COUNT):
		current_recruits.append(_generate_character(base_rank, nation))


func _roll_encounter(nation: int) -> void:
	if Util.get_random_float(0.0, 100.0) >= ENCOUNTER_CHANCE_PERCENT:
		return
	has_encounter = true
	encounter_stranger = _generate_character(_resolve_base_rank(nation), nation)

	var eligible: Array[Character] = []
	for character in CharacterRosterStore.all_characteres:
		if MarriageRule.can_propose(character, encounter_stranger):
			eligible.append(character)
	if not eligible.is_empty():
		encounter_courted = Util.get_random_from_array(eligible)


## CharacterController.get_random_character() 本身固定給 LevelSystem.new()(等級 1),
## 不會依評級調整——這裡另外依 PartyController.RANK_LEVEL_RANGE(評級→等級範圍的既有
## 難度曲線表,見該檔案)骰一個等級蓋回去,跟 PartyController.get_random_party() 的
## 「get_random_character() 拿到角色後另外指派 level_system」同一套慣例,酒館清單/特殊
## 推薦/搭訕對象才會顯示出跟評級相符的等級,不會全部都是 1 級。
func _generate_character(rank: int, nation: int) -> Character:
	var character := CharacterController.get_random_character(rank, nation)
	var level_range := PartyController.RANK_LEVEL_RANGE[rank]
	character.level_system = LevelSystem.new(Util.get_random_int(level_range.x, level_range.y + 1))
	return character


## 抽選基礎評級:未指定國家(-1,例如尚未整合城鎮的舊呼叫路徑)沿用原本固定的 F 級,
## 指定國家時改依 NationFavorStore 累積好感度換算(NationFavorRank.rank_for_favor())——
## 城鎮所屬國家好感度愈高,這座城鎮酒館能遇到的人才評級基準愈高。
func _resolve_base_rank(nation: int) -> int:
	if nation == -1:
		return GameEnums.RankType.F
	return NationFavorRank.rank_for_favor(NationFavorStore.get_favor(nation))


## 特殊推薦固定比基礎評級高一級,封頂 SSS(見 GameEnums.RankType 沒有更高的級別)。
func _special_recruit_rank(nation: int) -> int:
	return mini(_resolve_base_rank(nation) + 1, GameEnums.RankType.SSS)


func _on_month_passed() -> void:
	current_recruits.clear()
	special_recruit = null
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
		"special_recruit": SaveDataCodec.encode_character(special_recruit) if special_recruit != null else {},
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

	var special_recruit_data: Dictionary = data.get("special_recruit", {})
	if special_recruit_data.is_empty():
		special_recruit = null
	else:
		var special_recruit_id: String = special_recruit_data.get("id", "")
		special_recruit = by_id[special_recruit_id] if by_id.has(special_recruit_id) else SaveDataCodec.decode_character_base(special_recruit_data)

	_encounter_rolled = data.get("encounter_rolled", false)
	has_encounter = data.get("has_encounter", false)
	encounter_resolved = data.get("encounter_resolved", false)

	var stranger_data: Dictionary = data.get("encounter_stranger", {})
	encounter_stranger = SaveDataCodec.decode_character_base(stranger_data) if not stranger_data.is_empty() else null

	var courted_id: String = data.get("encounter_courted_id", "")
	encounter_courted = by_id.get(courted_id, null) if courted_id != "" else null
