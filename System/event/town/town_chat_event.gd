class_name TownChatEvent
extends LocationEvent

## 大地圖地點選單「聊天」按鈕用,見 Scenes/MapLocation/map_location.gd:隨機生一位
## Character 當聊天對象,先只給一句招呼詞佔位——之後要接真的劇情對話,再另外寫新的事件
## 類別去對應地點/角色,不要回頭改這個類別的用途。背景圖固定用
## GameEnums.TOWN_RESIDENTIAL_BACKGROUND_PATH,不分地形(聊天發生在城裡隨處可見的
## 住宅區)。跟 TownGateEvent 一樣,呼叫端只呼叫一次 trigger(return_scene_path)
## 就把整段流程交出去。
##
## 純聊天,不接任何委託——委託改由酒館老闆的「詢問委託」選項接管(見
## System/event/town/town_tavern_event.gd),這裡故意不引用 QuestStore/QuestLibrary,
## 也不需要城鎮所屬國家(nation)。

var _return_scene_path: String


static func trigger(return_scene_path: String) -> void:
	var event := TownChatEvent.new()
	event._start(return_scene_path)


func _start(return_scene_path: String) -> void:
	_return_scene_path = return_scene_path
	goto_dialogue(_build_chat(), return_scene_path)


func _build_chat() -> Dialogue:
	var player := LeaderStore.get_leader()
	var npc := CharacterController.get_random_character()

	var player_speaker := DialogueSpeaker.new(player.id, player.full_name, player.face_path, GameEnums.DialogueSide.LEFT)
	var npc_speaker := DialogueSpeaker.new(npc.id, npc.full_name, npc.face_path, GameEnums.DialogueSide.RIGHT)
	var lines: Array[DialogueLine] = [
		DialogueLine.new(player_speaker.id, "你好,這附近有什麼特別這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎這附近有什麼特別的事嗎的事嗎?"),
		DialogueLine.new(npc_speaker.id, "你好,異鄉人。這裡最近沒什麼特別的事。"),
	]
	return Dialogue.new([npc_speaker, player_speaker], lines, GameEnums.TOWN_RESIDENTIAL_BACKGROUND_PATH)
