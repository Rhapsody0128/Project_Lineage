extends Node

# =========================================================
# 通用場景交接信箱(autoload,SceneHandoffStore),取代原本 DialogueStore/ProposalStore 各自獨立開一支
# Autoload 的作法:場景切換沒辦法直接傳建構參數,所以呼叫端把資料存進來,再切場景,
# 目的地場景的 _ready() 讀出來用——這套「mailbox」邏輯每個用途都一樣,只是欄位命名
# 不同,沒必要每多一個 Event/UI 就多寫一支 pending_xxx 欄位 + Autoload .gd。以後新增
# 任何需要跨場景轉手資料的情境,直接呼叫這裡的 queue()/take()/peek(),payload 型別不限
# ——單一欄位可以直接傳現成物件(例如 FamilyTree.FOCUS_MAILBOX_KEY 直接傳一個
# Character,見 character_roster.gd),資料不只一個欄位時另外寫一個小型 RefCounted
# 資料類別(比照 System/marriage/marriage_proposal_request.gd 曾經的用法——這個類別已
# 隨告白流程改用 ActionPanel 疊加、不再切場景而刪除,不用碰這支檔案)。
#
# 用字串 key 分流不同用途,同一時間可以有好幾筆不同用途的資料同時待處理——例如
# LocationEvent.goto_dialogue() 一次呼叫會 queue DIALOGUE_MAILBOX_KEY 給下一個場景播放
# Dialogue,跟同時待處理的其他 key 不會互相覆蓋。
#
# take() 讀取後立刻清空(比照原本 ProposalStore 在 _ready() 讀完就清空的用法);
# peek() 讀取後保留不清——Dialogue 專用,因為 DialogueLine.choices 裡可能嵌著捕捉
# 呼叫端 self 的 lambda,RefCounted 事件物件要靠這份參照撐住活到 callback 真正被呼叫
# 的那一刻(見 System/event/location_event.gd 的生命週期註解),提早清掉會讓事件物件
# 提早被釋放。
# =========================================================

var _handoffs: Dictionary = {}


func queue(key: String, payload: Variant, next_scene_path: String = "", result_callback: Callable = Callable()) -> void:
	_handoffs[key] = SceneHandoff.new(payload, next_scene_path, result_callback)


func take(key: String) -> SceneHandoff:
	var handoff: SceneHandoff = _handoffs.get(key)
	_handoffs.erase(key)
	return handoff


func peek(key: String) -> SceneHandoff:
	return _handoffs.get(key)


func clear(key: String) -> void:
	_handoffs.erase(key)
