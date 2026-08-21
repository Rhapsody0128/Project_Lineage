extends Node

# =========================================================
# 全域「遊戲裡存在過的全部角色」存取點(autoload,見 project.godot)。跟
# CharacterRosterStore 不同:這裡不篩選「玩家能不能操控/上場」,凡是需要跟著世界時間
# 走(目前只有年紀增長,見 WorldTimeEventLibrary._age_up())的角色都要註冊進來——
# 包含未滿 CharacterController.MIN_AGE、還不能進 CharacterRosterStore 的小孩,以及
# 結婚後的配偶(TownTavernEvent 的 stranger,配偶依設計不會被放進 CharacterRosterStore,
# 但年紀還是要正常增長,見該檔案 _resolve_acceptance())。之後若做角色退休/死亡,從
# CharacterRosterStore 移除但保留在這裡即可,不需要另外設計欄位。
#
# CharacterRosterStore.all_characteres 是「玩家可操控」的子集合,不是另外維護一份獨立
# 資料——同一個 Character 物件會同時存在於這裡跟 CharacterRosterStore(如果它可操控的話)。
# register() 由建立/取得該角色永久身份的呼叫端(PartyEdit 新增角色、TownTavernEvent
# 告白成功、WorldTimeEventLibrary 產下孩子)各自呼叫一次,不會自動追蹤——
# CharacterController.get_random_character() 也被拿來生成戰鬥用的一次性雜兵
# (PartyController.get_random_party()、TownChatEvent/TownGateEvent 的场景 NPC),
# 那些不是玩家的角色,不應該進這個池子。
#
# register() 是角色總容量(見 BaseBuildingProgressStore.get_character_capacity(),
# 住宅區等級決定)唯一的把關點——招募/告白成親/生小孩全部經過這裡,容量滿了就不再收,
# 不用在每個呼叫端各自檢查一次。回傳值供呼叫端之後想顯示「已達上限」提示時使用,
# 目前呼叫端大多不看回傳值,只是先擋住數量超載。
# =========================================================

var all_characteres: Array[Character] = []


## 角色總容量是否已滿(見 BaseBuildingProgressStore.get_character_capacity())——
## register() 跟呼叫端(例如 CharacterRosterStore.is_full())共用同一個判斷式,
## 不用各自重算一次。
func is_full() -> bool:
	return all_characteres.size() >= BaseBuildingProgressStore.get_character_capacity()


func register(character: Character) -> bool:
	if all_characteres.has(character):
		return true
	if is_full():
		return false
	all_characteres.append(character)
	return true


## 存檔用:整份角色池(含小孩/配偶)攤平成字典陣列,見 Scripts/save_data_codec.gd。
func to_save_data() -> Array:
	var result: Array = []
	for character in all_characteres:
		result.append(SaveDataCodec.encode_character(character))
	return result


## 讀檔用:兩階段還原(先建好全部角色本身,再逐一補上 parent/mate/children——關係
## 另一端的角色要等全部角色都建好才能連,見 SaveDataCodec 開頭註解)。回傳
## id → Character 對照表,供 CharacterRosterStore/PartyStore 等其他 store 接著讀檔用,
## 不用各自重新掃描一次 all_characteres。
func load_save_data(data: Array) -> Dictionary:
	all_characteres.clear()
	var by_id: Dictionary = {}
	for entry in data:
		var character := SaveDataCodec.decode_character_base(entry)
		by_id[character.id] = character
		all_characteres.append(character)
	for entry in data:
		SaveDataCodec.link_character_relations(by_id[entry["id"]], entry, by_id)
	return by_id
