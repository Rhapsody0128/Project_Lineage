class_name HeroSortFilterBar
extends VBoxContainer

# =========================================================
# 角色清單共用的排序/篩選列:排序欄位用下拉選單(單選,固定由高到低,
# 沒有低到高的需求)+ 武器篩選用一排 CheckBox(可複選,全部取消勾選 =
# 不篩選)。這裡只組畫面與轉發點擊,實際排序/篩選規則一律轉呼叫
# System 層的 HeroSortFilter,不在這裡重算。
#
# 用法:掛在任何角色清單畫面裡,監聽 changed 訊號後呼叫
# sort_filter_bar.filter.apply(heroes) 重新整理清單即可,見 party_edit.gd。
# =========================================================

signal changed

var filter := HeroSortFilter.new()

const _FONT_SIZE := 14
const _FONT_COLOR := Color(0.9, 0.9, 0.95, 1)

## OptionButton 索引 0 固定是「不排序」,索引 1 起依序對應 GameEnums.HeroSortKey


func _ready() -> void:
	add_theme_constant_override("separation", 6)

	var sort_option := OptionButton.new()
	sort_option.add_theme_font_size_override("font_size", _FONT_SIZE)
	sort_option.add_item("不排序(由高到低)")
	for key in GameEnums.HeroSortKey.values():
		sort_option.add_item(GameEnums.hero_sort_key_label(key))
	sort_option.item_selected.connect(_on_sort_selected)
	add_child(sort_option)

	var filter_row := HFlowContainer.new()
	filter_row.add_theme_constant_override("h_separation", 12)
	filter_row.add_theme_constant_override("v_separation", 4)
	add_child(filter_row)
	for weapon_type in GameEnums.WeaponType.values():
		var checkbox := CheckBox.new()
		checkbox.text = GameEnums.weapon_label(weapon_type)
		checkbox.add_theme_font_size_override("font_size", _FONT_SIZE)
		checkbox.add_theme_color_override("font_color", _FONT_COLOR)
		checkbox.toggled.connect(_on_weapon_toggled.bind(weapon_type))
		filter_row.add_child(checkbox)


func _on_sort_selected(index: int) -> void:
	filter.sort_key = index - 1
	changed.emit()


func _on_weapon_toggled(_button_pressed: bool, weapon_type: int) -> void:
	filter.toggle_weapon_filter(weapon_type)
	changed.emit()
