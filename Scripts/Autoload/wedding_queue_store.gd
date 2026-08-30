extends Node

# =========================================================
# 婚禮倒數(autoload,見 project.godot)——告白(TownTavernEvent)/聯姻(BaseMarriageEvent)
# 接受成功的當下不再立刻結婚,改呼叫這裡的 queue_wedding() 把「誰跟誰」+「結果公告文案」
# 記錄下來,DELAY_DAYS(30)天倒數歸零那天才真正呼叫 System/marriage/wedding_event.gd 的
# WeddingEvent.trigger() 補上 Character.marry()/婚禮 Dialogue/CharacterPanel/MESSAGE
# ——寫法比照 BarracksExpeditionStore 的「送出去 N 天後才結算」倒數,_ready() 向
# WorldTimeStore.controller 註冊每日結算。
#
# spouse_character(新配偶 NPC)在 queue_wedding() 當下就註冊進 AllCharacterStore,不是等
# 30 天後才註冊——存檔中途可能剛好落在這 30 天倒數期間,新配偶要能被存檔/讀檔記住,
# 之後只存 character id、靠 BaseDispatchStore.find_character() 換回物件參照(它本來就是
# 掃 AllCharacterStore,見該檔案)。
#
# 同一天可能有好幾場婚禮同時倒數歸零,但 WeddingEvent 內部會真的切場景播 Dialogue,
# 不能同時疊兩場——_busy 旗標 + _ready_queue 讓它們排隊逐一觸發,寫法比照
# LifeEventQueueStore 的排隊播放,差別是這裡的「觸發」本身就是一次完整的
# LocationEvent(不是切去一個等玩家操作的畫面),所以下一場要等上一場的 on_done
# callback 回呼才能接著觸發。
# =========================================================

const DELAY_DAYS := 30
const DEFAULT_RETURN_SCENE_PATH := "res://Scenes/Map/map.tscn"

var _pending: Array[Dictionary] = []
var _ready_queue: Array[Dictionary] = []
var _busy: bool = false
## _on_day_passed() 當下讀一次的「玩家目前所在場景」,整批(同一天可能好幾場婚禮排隊)
## 共用這一份值,不讓 WeddingEvent 自己在可能已經 stale 的時機點重讀 tree.current_scene——
## 見 System/marriage/wedding_event.gd 檔頭註解陷阱說明。
var _return_scene_path: String = DEFAULT_RETURN_SCENE_PATH
## 正在觸發中(已從 _ready_queue 撈出、WeddingEvent 播完前)的這一筆,is_pending() 也要算
## 在內——不然 _process_next_if_idle() 呼叫 WeddingEvent.trigger() 到 Character.marry()
## 真正寫入 mate 之間那短短一瞬間,MarriageRule.can_propose() 會誤判這位角色「沒有婚約」。
var _current: Dictionary = {}


func _ready() -> void:
	WorldTimeStore.controller.register_day_event(_on_day_passed)


func queue_wedding(own_character: Character, spouse_character: Character, announcement_text: String, delay_days: int = DELAY_DAYS) -> void:
	AllCharacterStore.register(spouse_character)
	_pending.append({
		"own_id": own_character.id,
		"spouse_id": spouse_character.id,
		"days_remaining": delay_days,
		"announcement_text": announcement_text,
	})


## 這位角色是不是已經排進婚禮倒數(含還在倒數中/當天已就緒待觸發/正在觸發演出中)——
## MarriageRule.can_propose()/eligible_proposers() 靠這裡擋掉重複婚約,見兩邊呼叫端註解。
func is_pending(character_id: String) -> bool:
	if _current.get("own_id", "") == character_id or _current.get("spouse_id", "") == character_id:
		return true
	for entry in _pending:
		if entry["own_id"] == character_id or entry["spouse_id"] == character_id:
			return true
	for entry in _ready_queue:
		if entry["own_id"] == character_id or entry["spouse_id"] == character_id:
			return true
	return false


func _on_day_passed() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree.current_scene != null:
		_return_scene_path = tree.current_scene.scene_file_path

	var still_pending: Array[Dictionary] = []
	for entry in _pending:
		entry["days_remaining"] -= 1
		if entry["days_remaining"] <= 0:
			_ready_queue.append(entry)
		else:
			still_pending.append(entry)
	_pending = still_pending
	_process_next_if_idle()


func _process_next_if_idle() -> void:
	if _busy or _ready_queue.is_empty():
		return
	var entry: Dictionary = _ready_queue.pop_front()
	var own_character := BaseDispatchStore.find_character(entry["own_id"])
	var spouse_character := BaseDispatchStore.find_character(entry["spouse_id"])
	# 防呆:倒數期間本人或配偶意外從 AllCharacterStore 消失(目前設計下不會發生,角色只會
	# 標記 is_dead 不會被移除,見 CLAUDE.md「老年與死亡」),跳過這筆、繼續處理下一筆。
	if own_character == null or spouse_character == null:
		_process_next_if_idle()
		return
	_busy = true
	_current = entry
	WeddingEvent.trigger(own_character, spouse_character, entry["announcement_text"], _return_scene_path, func() -> void:
		_busy = false
		_current = {}
		_process_next_if_idle()
	)


func to_save_data() -> Dictionary:
	return {"pending": _pending.duplicate(true), "ready_queue": _ready_queue.duplicate(true)}


func load_save_data(data: Dictionary) -> void:
	_pending.clear()
	for entry in data.get("pending", []):
		_pending.append({
			"own_id": str(entry.get("own_id", "")),
			"spouse_id": str(entry.get("spouse_id", "")),
			"days_remaining": int(entry.get("days_remaining", DELAY_DAYS)),
			"announcement_text": str(entry.get("announcement_text", "")),
		})
	_ready_queue.clear()
	for entry in data.get("ready_queue", []):
		_ready_queue.append({
			"own_id": str(entry.get("own_id", "")),
			"spouse_id": str(entry.get("spouse_id", "")),
			"days_remaining": int(entry.get("days_remaining", 0)),
			"announcement_text": str(entry.get("announcement_text", "")),
		})
	_busy = false
