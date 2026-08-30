class_name WorkshopRecipe
extends RefCounted

## 工匠坊單一配方的靜態資料(見 System/base/workshop_recipe_library.gd)。inputs 是消耗
## 一批要花的原料(GameEnums.ResourceType -> 數量),output_amount 是消耗一批 inputs
## 換到的工具量。inputs 空字典代表「不產出」
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


## 「配方革新」科技線(TechEffectType.RECIPE_EXTRA_OUTPUT_ADD)加在基礎 output_amount 上,
## inputs 為空(不產出的配方)一律不受影響。WorkshopProduction.resolve() 一律呼叫這支,
## 不要直接讀 output_amount 欄位。
func effective_output_amount() -> int:
	if inputs.is_empty():
		return output_amount
	return output_amount + int(TechStore.get_bonus(GameEnums.TechEffectType.RECIPE_EXTRA_OUTPUT_ADD))
