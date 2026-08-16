class_name SceneHandoff
extends RefCounted

## 搭配 SceneHandoffStore 用的通用場景交接資料信封。payload 是呼叫端跟接收端約定好的
## 任意型別資料(例如 Dialogue、MarriageProposalRequest),next_scene_path/
## result_callback 是選填的附加資訊——不是每種用途都兩者都會用到(例如 Dialogue
## 只用 next_scene_path,MarriageProposal 只用 result_callback),接收端自己挑需要
## 的欄位讀。

var payload: Variant
var next_scene_path: String = ""
var result_callback: Callable = Callable()


func _init(p_payload: Variant = null, p_next_scene_path: String = "", p_result_callback: Callable = Callable()) -> void:
	payload = p_payload
	next_scene_path = p_next_scene_path
	result_callback = p_result_callback
