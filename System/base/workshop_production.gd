class_name WorkshopProduction
extends RefCounted

## 工匠坊配方消耗計算:原料不足時不再整個月掛零(all-or-nothing 已改掉),改成把手上
## 有多少原料就投入多少去加工,產出跟原料同比例打折——原料只夠做八成,這個月就只出
## 八成貨,不會因為湊不滿一整批就整批作廢。純函式,不碰任何 autoload,呼叫端
## (BaseDispatchStore/base_action_panel.gd 預覽)提供目前庫存快照(只需要 recipe.inputs
## 涉及的資源)。
##
## 回傳值刻意是浮點數,不在這裡就近取整——原料不夠時「這個月本來能做多少」常常不是整數
## (例如原料只夠 2.5 份產出),呼叫端(BaseResourceStore.amounts)按浮點數原樣入庫,
## 讓沒做完的零頭留在庫存裡累積到下個月,下個月配方又消耗到新到位的原料時,一樣按浮點數
## 算,兩個月加起來自然湊出下一個整數;只有畫面顯示要無條件捨去成整數
## (BaseResourceStore.get_display_amount()),不能反過來讓「顯示捨去」動到真正存量,
## 那樣零頭會每個月被吃掉、永遠湊不滿下一個整數。

## 回傳 {"output": 這個月的產出量, "consumed": 這個月實際消耗的原料 Dictionary},兩者都是
## float。theoretical_output(產出上限/「最大產能」)當作這個月理論上能做到的產出天花板,
## 原料充足時直接打滿;原料不夠打滿時,依「投入資源 ÷ 配方需求」換算成能做到的產出量
## (可生產量 = min(投入資源 ÷ 配方需求, 產出上限)),消耗量按這個產出量等比例換算回去
## ——絕不會消耗超過 available 裡實際有的量。原料完全枯竭(available 為 0)時回傳 0/空
## 字典,不會硬生出負庫存。
static func resolve(recipe: WorkshopRecipe, theoretical_output: int, available: Dictionary) -> Dictionary:
	if theoretical_output <= 0 or recipe.output_amount <= 0 or recipe.inputs.is_empty():
		return {"output": 0.0, "consumed": {}}

	var producible := float(theoretical_output)
	for resource_type in recipe.inputs:
		var input_per_output: float = float(recipe.inputs[resource_type]) / float(recipe.output_amount)
		var affordable: float = float(available.get(resource_type, 0)) / input_per_output
		producible = minf(producible, affordable)

	if producible <= 0.0:
		return {"output": 0.0, "consumed": {}}

	var consumed: Dictionary = {}
	for resource_type in recipe.inputs:
		consumed[resource_type] = producible * float(recipe.inputs[resource_type]) / float(recipe.output_amount)

	return {"output": producible, "consumed": consumed}
