class_name WorkshopRecipeLibrary
extends RefCounted

## 工匠坊配方總表(見「根據地內政系統設計」文件十二節)。沒有絕對最優配方——精工複合
## 兌換比最好但要求四條資源鏈同時有餘裕,單資源配方則看玩家當下庫存偏向哪邊。「不生產」
## 讓玩家明確選擇這個月不消耗任何原料(跟「原料不足自動作白工」是兩回事——這是主動選擇)。

static func get_all() -> Array[WorkshopRecipe]:
	return [
		WorkshopRecipe.new("none", "不生產", {}, 0),
		WorkshopRecipe.new("wood", "粗製木工", {GameEnums.ResourceType.WOOD: 3}, 1),
		WorkshopRecipe.new("stone", "石雕工藝", {GameEnums.ResourceType.STONE: 3}, 1),
		WorkshopRecipe.new("ore", "鍛造", {GameEnums.ResourceType.ORE: 2}, 1),
		WorkshopRecipe.new("fur", "皮革工藝", {GameEnums.ResourceType.FUR: 2}, 1),
	]


static func get_by_id(id: String) -> WorkshopRecipe:
	for recipe in get_all():
		if recipe.id == id:
			return recipe
	return get_all()[0]
