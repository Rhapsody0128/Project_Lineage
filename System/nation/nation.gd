class_name Nation
extends RefCounted

## 單一國家的靜態身分資料,對應 GameEnums.BloodlineNation 六國之一。名稱與低血/高血
## 稱呼直接呼叫 GameEnums 既有函式組出來,不在這裡重複維護一份標籤表。玩家對這個國家的
## 好感度是易變的玩家資料,不放在這裡,見 Scripts/Autoload/nation_favor_store.gd。

var id: int
var name: String
var low_blood_label: String
var high_blood_label: String


func _init(p_id: int) -> void:
	id = p_id
	name = GameEnums.bloodline_nation_label(p_id)
	low_blood_label = GameEnums.bloodline_full_label(p_id, GameEnums.BloodlineRank.COMMON)
	high_blood_label = GameEnums.bloodline_full_label(p_id, GameEnums.BloodlineRank.NOBLE)
