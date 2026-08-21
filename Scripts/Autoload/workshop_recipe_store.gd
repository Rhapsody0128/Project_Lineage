extends Node

# =========================================================
# 工匠坊目前選定的配方(autoload,見 project.godot)。只有一棟工匠坊,不用像
# BaseDispatchStore 那樣用 Dictionary keyed by BuildingType——單一欄位存目前選定的
# WorkshopRecipe.id,預設 "wood"(木製工具,最容易取得的配方)。
# =========================================================

signal changed

var _selected_recipe_id: String = "wood"


func get_selected() -> WorkshopRecipe:
	return WorkshopRecipeLibrary.get_by_id(_selected_recipe_id)


func select(recipe_id: String) -> void:
	_selected_recipe_id = recipe_id
	changed.emit()


## WorkshopRecipe.id 是寫死的固定字串(見 workshop_recipe_library.gd),不像 Skill/
## Ultimate 那樣是隨機 UUID,可以直接存/讀。
func to_save_data() -> String:
	return _selected_recipe_id


func load_save_data(recipe_id: String) -> void:
	_selected_recipe_id = recipe_id
	changed.emit()
