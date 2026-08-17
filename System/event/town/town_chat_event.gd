class_name TownChatEvent
extends LocationEvent

## 大地圖地點選單「聊天」按鈕用,見 Scenes/MapLocation/map_location.gd:隨機生一位
## Character 當作聊天對象,先只給一句招呼詞佔位——之後要接真的劇情對話,再另外寫新的事件
## 類別去對應地點/角色,不要回頭改這個類別的用途。跟 TownGateEvent 一樣,呼叫端只
## 呼叫一次 trigger(return_scene_path) 就把整段流程交出去。


static func trigger(return_scene_path: String) -> void:
	var event := TownChatEvent.new()
	event._start(return_scene_path)


func _start(return_scene_path: String) -> void:
	goto_dialogue(_build_chat(), return_scene_path)


func _build_chat() -> Dialogue:
	var player := CharacterController.get_random_character()
	var npc := CharacterController.get_random_character()
	var npc2 := CharacterController.get_random_character()

	var player_speaker := DialogueSpeaker.new(player.id, player.full_name, player.face_path, GameEnums.DialogueSide.LEFT)
	var npc_speaker := DialogueSpeaker.new(npc.id, npc.full_name, npc.face_path, GameEnums.DialogueSide.RIGHT)
	var npc2_speaker := DialogueSpeaker.new(npc2.id, npc2.full_name, npc2.face_path, GameEnums.DialogueSide.RIGHT)
	var lines: Array[DialogueLine] = [
		DialogueLine.new(player_speaker.id, "你好,這附近有什麼特別的事嗎?"),
		DialogueLine.new(npc_speaker.id, "你好,異鄉人。這裡最近沒什麼特別的事。"),
		DialogueLine.new(npc2_speaker.id, "別多嘴,現在說甚麼都有可能出事。"),
	]
	return Dialogue.new([npc_speaker, npc2_speaker, player_speaker], lines)
