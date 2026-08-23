class_name CharacterSortFilterBar
extends VBoxContainer

# =========================================================
# 角色清單共用的排序/篩選列:排序欄位用下拉選單(單選,固定由高到低,
# 沒有低到高的需求)+ 武器篩選用一排 CheckBox(可複選,全部取消勾選 =
# 不篩選)。這裡只組畫面與轉發點擊,實際排序/篩選規則一律轉呼叫
# System 層的 CharacterSortFilter,不在這裡重算。
#
# 用法:掛在任何角色清單畫面裡,監聽 changed 訊號後呼叫
# sort_filter_bar.filter.apply(characteres) 重新整理清單即可,見 party_edit.gd。
# =========================================================

signal changed

var filter := CharacterSortFilter.new()

const _FONT_SIZE := 14
const _FONT_COLOR := UiStyle.PARCHMENT_TEXT_COLOR

## OptionButton 索引 0 固定是「不排序」,索引 1 起依序對應 GameEnums.CharacterSortKey

var _initial_sort_key: int = -1
var _show_weapon_filter: bool = true


## 呼叫端(例如 CharacterSelectBar.setup())要在 add_child() 之前呼叫,才能在 _ready() 建
## OptionButton/篩選列時套用——比照這份檔案一貫「先設好初始狀態再進場景樹」的用法。
## initial_sort_key 是 -1(不排序)以外的值時對應預選 GameEnums.CharacterSortKey;
## show_weapon_filter 為 false 時整排武器篩選 CheckBox 不會被建立(某些情境武器類型跟
## 篩選目的無關,例如根據地資源派遣選人清單)。
func configure(initial_sort_key: int = -1, show_weapon_filter: bool = true) -> void:
	_initial_sort_key = initial_sort_key
	_show_weapon_filter = show_weapon_filter


func _ready() -> void:
	add_theme_constant_override("separation", 6)

	var sort_option := OptionButton.new()
	sort_option.add_theme_font_size_override("font_size", _FONT_SIZE)
	sort_option.add_item("不排序(由高到低)")
	for key in GameEnums.CharacterSortKey.values():
		sort_option.add_item(GameEnums.character_sort_key_label(key))
	sort_option.item_selected.connect(_on_sort_selected)
	sort_option.select(_initial_sort_key + 1)
	filter.sort_key = _initial_sort_key
	add_child(sort_option)

	if not _show_weapon_filter:
		return

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
