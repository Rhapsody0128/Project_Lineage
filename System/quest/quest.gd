class_name Quest
extends RefCounted

## 單一任務的資料容器,純資料,不含任何生成/文案邏輯(那些集中在
## System/quest/quest_library.gd,比照 NewsEntry vs NewsController 的分工)。

var id: String
var quest_type: GameEnums.QuestType
## Scenes/QuestList/quest_list.gd 左側邊欄依這個欄位分頁(主線/支線/委託),見
## GameEnums.QuestCategory 欄位註解。
var category: GameEnums.QuestCategory
var rank: GameEnums.RankType
var nation: GameEnums.BloodlineNation
var status: GameEnums.QuestStatus
var accepted_day: int
## 世界時間 WorldTime.get_day_count() 的絕對天數,QuestStore._on_day_passed() 每天拿
## 目前天數跟這個比較,超過就標記逾期,見 System/time/world_time.gd。
var deadline_day: int
## QuestType.DELIVERY 專用:要繳交的資源種類/數量,見 QuestStore.complete_delivery_quest()。
## 其他任務類型不使用,固定 -1/0。
var resource_type: GameEnums.ResourceType
var resource_amount: int
## QuestType.COURIER 專用:信件要送達的目的地國家,見 QuestStore.notify_courier_arrived()。
## 其他任務類型不使用,固定 -1。
var destination_nation: GameEnums.BloodlineNation


func _init(p_id: String, p_quest_type: GameEnums.QuestType, p_category: GameEnums.QuestCategory, p_rank: GameEnums.RankType, p_nation: GameEnums.BloodlineNation, p_accepted_day: int, p_deadline_day: int, p_resource_type: GameEnums.ResourceType = -1, p_resource_amount: int = 0, p_destination_nation: GameEnums.BloodlineNation = -1) -> void:
	id = p_id
	quest_type = p_quest_type
	category = p_category
	rank = p_rank
	nation = p_nation
	accepted_day = p_accepted_day
	deadline_day = p_deadline_day
	resource_type = p_resource_type
	resource_amount = p_resource_amount
	destination_nation = p_destination_nation
	status = GameEnums.QuestStatus.IN_PROGRESS
