class_name Tech
extends RefCounted

## 單一科技的靜態資料(見 System/base/tech_library.gd)。tier 1~3 對應科學研究所
## Lv3/Lv6/Lv9 三個解鎖門檻(見 TechLibrary.level_requirement())。

var id: String
var category: String
var name: String
var description: String
var tier: int
var cost: int


func _init(p_id: String, p_category: String, p_name: String, p_description: String, p_tier: int, p_cost: int) -> void:
	id = p_id
	category = p_category
	name = p_name
	description = p_description
	tier = p_tier
	cost = p_cost
