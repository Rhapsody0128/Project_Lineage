class_name WorkshopProduction
extends RefCounted

## 工匠坊配方消耗計算:原料不足時整個月不生產、不消耗(不是部分打折),照扣照給——
## 純函式,不碰任何 autoload,呼叫端(BaseDispatchStore/base_action_panel.gd 預覽)
## 提供目前庫存快照(只需要 recipe.inputs 涉及的資源)。

## 回傳 {"output": 這個月的製作工藝產出量, "consumed": 這個月實際消耗的原料 Dictionary}。
## 資源不足時兩者都是 0/空字典——這個月作白工,不會扣成負數,也不會只做一半。
static func resolve(recipe: WorkshopRecipe, theoretical_output: int, available: Dictionary) -> Dictionary:
	if theoretical_output <= 0 or recipe.output_amount <= 0 or recipe.inputs.is_empty():
		return {"output": 0, "consumed": {}}

	var batches := ceili(float(theoretical_output) / recipe.output_amount)
	var consumed: Dictionary = {}
	for resource_type in recipe.inputs:
		consumed[resource_type] = recipe.inputs[resource_type] * batches

	for resource_type in consumed:
		if available.get(resource_type, 0) < consumed[resource_type]:
			return {"output": 0, "consumed": {}}

	return {"output": batches * recipe.output_amount, "consumed": consumed}
