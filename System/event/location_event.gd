class_name LocationEvent
extends RefCounted

## 大地圖地點事件的共用基底(System/event/castle/ 底下的 CastleGateEvent/
## CastleChatEvent 都繼承這裡):呼叫端(Scenes 層,例如 map_location.gd 的按鈕)只呼叫
## 一次子類別的 trigger(return_scene_path),接下來對話/戰鬥怎麼串、播完要回哪裡,全部
## 交給事件物件自己接管,對應 CLAUDE.md「System 管邏輯,Scenes 管畫面」的分工——事件的
## 文案(台詞常數)跟功能流程(trigger()/內部私有方法)集中寫在同一個 class 裡,不要
## 散落在呼叫端。
##
## 事件本身是 RefCounted,不是 Node——整段流程往往橫跨好幾次場景切換(例如
## CastleGateEvent 是 MapLocation → Dialogue → Battle → Dialogue → MapLocation),中途
## 發起事件的那個場景節點早就因為切場景被釋放掉了。如果事件方法(例如戰鬥打完的結果
## callback)綁在 Node 上,Callable 會變成參照一個懸空物件、一呼叫就炸掉;綁在 RefCounted
## 事件物件上則沒有這個問題,Callable 對 self 的參照會靠引用計數把物件撐住,活到真正被
## 呼叫的那一刻。也因為這樣,底下 goto_dialogue() 用 Engine.get_main_loop() 取代
## self.get_tree(),同樣不依賴任何場景節點還活著。

const DIALOGUE_SCENE_PATH := "res://Scenes/Dialogue/dialogue_box.tscn"


## 把 Dialogue 塞進 DialogueStore、切去對話場景播放,播完由 next_scene_path 自動接手
## 轉場(見 Scripts/Autoload/dialogue_store.gd)。子類別要顯示任何一段對話都呼叫這裡,
## 不要自己重複寫一份「Engine.get_main_loop() 取代 get_tree()」。
func goto_dialogue(dialogue: Dialogue, next_scene_path: String) -> void:
	DialogueStore.queue(dialogue, next_scene_path)
	var tree := Engine.get_main_loop() as SceneTree
	var error := tree.change_scene_to_file(DIALOGUE_SCENE_PATH)
	if error != OK:
		printerr("Error changing scene to dialogue: ", error)
