class_name DialogueChoice
extends RefCounted

## 對話選項:label 是選項按鈕文字,next_scene_path 是選了這個選項後要切去的場景。
## 跟 Dialogue 本身「播完要去哪」(見 Scripts/Autoload/dialogue_store.gd 的
## next_scene_path)共用同一套「場景路徑」語彙,選項只是把這個決定從「整段對話
## 固定一個目的地」拆成「依玩家選哪個選項各自決定」,場景路徑一律由呼叫端
## (Scenes 層,例如 System/event/ 底下各個事件的 build_xxx() 呼叫端)傳入,不要寫死在
## System/ 底下。
##
## on_selected 是選了這個選項、切場景前要執行的額外副作用(例如把資料寫進場景交接用
## 的 autoload,見 System/event/town/town_gate_event.gd 的 TownGateEvent._start()
## 傳的那個彈 AskBattle 的 Callable),同樣一律由呼叫端傳入——DialogueChoice 不知道
## 也不需要知道 Callable 裡實際做了什麼,才不會讓這裡反過來牽扯特定事件的細節。

var label: String
var next_scene_path: String
var on_selected: Callable

func _init(p_label: String, p_next_scene_path: String, p_on_selected: Callable = Callable()) -> void:
	label = p_label
	next_scene_path = p_next_scene_path
	on_selected = p_on_selected
