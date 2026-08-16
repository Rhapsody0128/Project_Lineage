extends Node

# =========================================================
# 全域「遊戲裡存在過的全部角色」存取點(autoload,見 project.godot)。跟
# CharacterRosterStore 不同:這裡不篩選「玩家能不能操控/上場」,凡是需要跟著世界時間
# 走(目前只有年紀增長,見 WorldTimeEventLibrary._age_up())的角色都要註冊進來——
# 包含未滿 CharacterController.MIN_AGE、還不能進 CharacterRosterStore 的小孩,以及
# 結婚後的配偶(CastleTavernEvent 的 stranger,配偶依設計不會被放進 CharacterRosterStore,
# 但年紀還是要正常增長,見該檔案 _resolve_acceptance())。之後若做角色退休/死亡,從
# CharacterRosterStore 移除但保留在這裡即可,不需要另外設計欄位。
#
# CharacterRosterStore.all_characteres 是「玩家可操控」的子集合,不是另外維護一份獨立
# 資料——同一個 Character 物件會同時存在於這裡跟 CharacterRosterStore(如果它可操控的話)。
# register() 由建立/取得該角色永久身份的呼叫端(PartyEdit 新增角色、CastleTavernEvent
# 告白成功、WorldTimeEventLibrary 產下孩子)各自呼叫一次,不會自動追蹤——
# CharacterController.get_random_character() 也被拿來生成戰鬥用的一次性雜兵
# (PartyController.get_random_party()、CastleChatEvent/CastleGateEvent 的场景 NPC),
# 那些不是玩家的角色,不應該進這個池子。
# =========================================================

var all_characteres: Array[Character] = []


func register(character: Character) -> void:
	if not all_characteres.has(character):
		all_characteres.append(character)
