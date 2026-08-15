class_name DialogueChoice
extends RefCounted

## 對話選項:label 是選項按鈕文字,next_scene_path 是選了這個選項後要切去的場景。
## 跟 Dialogue 本身「播完要去哪」(見 Scripts/Autoload/dialogue_store.gd 的
## next_scene_path)共用同一套「場景路徑」語彙,選項只是把這個決定從「整段對話
## 固定一個目的地」拆成「依玩家選哪個選項各自決定」,場景路徑一律由呼叫端
## (Scenes 層,例如 DialogueLibrary 的 build_xxx() 呼叫端)傳入,不要寫死在
## System/ 底下。

var label: String
var next_scene_path: String

func _init(p_label: String, p_next_scene_path: String) -> void:
	label = p_label
	next_scene_path = p_next_scene_path
