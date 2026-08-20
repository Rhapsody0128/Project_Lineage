class_name WorkshopRecipe
extends RefCounted

## 工匠坊單一配方的靜態資料(見 System/base/workshop_recipe_library.gd)。inputs 是消耗
## 一批要花的原料(GameEnums.ResourceType -> 數量,可以是多種資源湊一批,例如精工複合),
## output_amount 是消耗一批 inputs 換到的製作工藝量。inputs 空字典代表「不產出」
## (WorkshopProduction.resolve() 對空 inputs 直接回傳 0/0,不消耗也不生產)。

var id: String
var name: String
var inputs: Dictionary
var output_amount: int


func _init(p_id: String, p_name: String, p_inputs: Dictionary, p_output_amount: int) -> void:
	id = p_id
	name = p_name
	inputs = p_inputs
	output_amount = p_output_amount
