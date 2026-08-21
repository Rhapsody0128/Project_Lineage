class_name WorkshopRecipeLibrary
extends RefCounted

## 工匠坊配方總表(見「根據地內政系統設計」文件十二節)。三種配方只是原料來源不同
## (木材/石材/鐵礦),換算出來的東西都是同一種「工具」數量,沒有絕對最優配方,純看玩家
## 當下庫存偏向哪邊原料。原料不足時 WorkshopProduction.resolve() 本來就會整個月自動不
## 生產、不消耗,不需要另外一個「不生產」選項讓玩家手動選。
##
## 消耗量不是隨手定的,是跟 System/base/base_exchange.gd 的「價值點數」換算表同一套
## 稀有度基準(K=60÷base_yield,四捨五入,見該檔案開頭註解):木材5、石材10、鐵礦12、
## 工具40(20×2,精製品額外加倍)。qty = round(value(工具) ÷ value(原料))——原料越稀有
## (價值點數越高),換到 1 個工具要花的原料量越少:木材 40÷5=8、石材 40÷10=4、
## 鐵礦 40÷12≈3。原本三種配方都寫死 2~3,沒有反映石材其實比木材稀有,已修正。
static func get_all() -> Array[WorkshopRecipe]:
	return [
		WorkshopRecipe.new("wood", "木製工具", {GameEnums.ResourceType.WOOD: 8}, 1),
		WorkshopRecipe.new("stone", "石製工具", {GameEnums.ResourceType.STONE: 4}, 1),
		WorkshopRecipe.new("ore", "鐵製工具", {GameEnums.ResourceType.ORE: 3}, 1),
	]


static func get_by_id(id: String) -> WorkshopRecipe:
	for recipe in get_all():
		if recipe.id == id:
			return recipe
	return get_all()[0]
