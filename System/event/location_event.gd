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
## 事件物件上則沒有這個問題。也因為這樣,底下 goto_dialogue() 用 Engine.get_main_loop()
## 取代 self.get_tree(),同樣不依賴任何場景節點還活著。
##
## 陷阱:「裸方法參照」(例如 `SomeStore.queue(..., _on_result)`)底層只存 ObjectID,
## 不會讓 RefCounted 的引用計數增加——子類別自己(event 物件)沒有其他地方被強參照時,
## 觸發方法一返回就會立刻被釋放,callback 到了該被呼叫的時候早已失效(Callable.is_valid()
## 悄悄回傳 false,不會報錯,呼叫端多半會 fallback 成別的預設行為,很難察覺)。要讓事件
## 物件撐到 callback 真正被呼叫,必須包一層 lambda 讓它捕捉 self(例如
## `func(): AskBattle.ask(..., _on_result)` 或 `func(x): _on_result(x)`),靠 Variant
## 對 RefCounted 的 Ref<> 語意撐住,不能直接傳裸方法參照(見 CastleGateEvent 的
## on_challenge_accepted 用法,以及 CastleTavernEvent._start() 對 ProposalStore.queue()
## 的用法)。

const DIALOGUE_SCENE_PATH := "res://Scenes/Dialogue/dialogue_box.tscn"
## SceneHandoffStore 的 key,跟 Scenes/Dialogue/dialogue_box.gd 共用同一把——兩邊都用這個
## 常數存取,不要各自硬編字串 "dialogue"。
const DIALOGUE_MAILBOX_KEY := "dialogue"


## 把 Dialogue 塞進 SceneHandoffStore、切去對話場景播放,播完由 next_scene_path 自動接手
## 轉場(見 Scripts/Autoload/scene_handoff_store.gd)。子類別要顯示任何一段對話都呼叫這裡,
## 不要自己重複寫一份「Engine.get_main_loop() 取代 get_tree()」。
func goto_dialogue(dialogue: Dialogue, next_scene_path: String) -> void:
	SceneHandoffStore.queue(DIALOGUE_MAILBOX_KEY, dialogue, next_scene_path)
	var tree := Engine.get_main_loop() as SceneTree
	var error := tree.change_scene_to_file(DIALOGUE_SCENE_PATH)
	if error != OK:
		printerr("Error changing scene to dialogue: ", error)
