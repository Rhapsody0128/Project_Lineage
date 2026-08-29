class_name WeaponEquipPanel
extends HBoxContainer

# =========================================================
# 鐵匠鋪「變更武器」畫面(跟「打造武器」是分開的兩個獨立功能,見 Scenes/Base/
# base_action_panel.gd 的 _open_weapon_equip_panel())——幫指定角色把手持武器類型換成
# 另一種六大武器之一,比較的是「不同武器類型」的全域素質加成(例如法杖 → 劍,兩種類型
# 各自的全域裝備模板數值不同,六大素質可能同時都有差異,不像打造武器只比較同類型
# 新舊差異)。換裝後角色的技能表要重骰(bind_weapon 技能才會對得上新武器),寫法比照
# System/academy/academy_rule.gd 的 enroll()(留學換武器同一套慣例),見
# WeaponLibrary.change_weapon_type()。
#
# 版面三塊(左/右上/右下):左——CharacterDetailView 顯示目前選定角色;右上——「變更為」
# 六武器類型單選 + 目前武器 vs 選定目標武器的素質差異比較(綠漲紅跌);右下——
# CharacterSelectBar(全部角色,不限武器類型,任何角色都能轉職)。標題列「確認變更」鈕
# 需選好角色與相異的目標類型才會啟用。
# =========================================================

const _POSITIVE_COLOR := Color(0.16, 0.42, 0.16)
const _NEGATIVE_COLOR := Color(0.75, 0.25, 0.25)

var _detail_view: CharacterDetailView
var _compare_column: VBoxContainer
var _select_bar: CharacterSelectBar
var _confirm_button: Button
var _target_group: ButtonGroup

var _character: Character
var _target_type: int = -1
var _on_close: Callable


func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 16)

	var detail_panel := PanelContainer.new()
	detail_panel.add_theme_stylebox_override("panel", UiStyle.right_border_style())
	add_child(detail_panel)

	_detail_view = CharacterDetailView.new()
	_detail_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_view.scrollable_tabs = false
	detail_panel.add_child(_detail_view)

	var right_column := VBoxContainer.new()
	right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_column.add_theme_constant_override("separation", 16)
	add_child(right_column)

	right_column.add_child(_build_change_panel())
	right_column.add_child(_build_picker_panel())

	_confirm_button = Button.new()
	_confirm_button.text = "確認變更"
	UiStyle.style_panel_action_button(_confirm_button)
	_confirm_button.disabled = true
	_confirm_button.pressed.connect(_on_confirm_pressed)
	ActionPanel.set_title_action_button(_confirm_button)


## 右上「變更為」區塊:下方畫一條線跟角色清單分隔,六武器類型單選鈕 + 差異比較表格。
func _build_change_panel() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.bottom_border_style())

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	var title := Label.new()
	title.text = "變更為"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	column.add_child(title)

	var type_row := HBoxContainer.new()
	type_row.add_theme_constant_override("separation", 8)
	column.add_child(type_row)

	_target_group = ButtonGroup.new()
	for weapon_type in GameEnums.WeaponType.values():
		var button := Button.new()
		button.text = GameEnums.weapon_label(weapon_type)
		button.icon = load(GameEnums.weapon_icon_path(weapon_type)) as Texture2D
		button.add_theme_constant_override("icon_max_width", 22)
		button.toggle_mode = true
		button.button_group = _target_group
		UiStyle.apply_wood_plaque_button(button, 12.0, 6.0)
		button.add_theme_font_size_override("font_size", 15)
		button.pressed.connect(func() -> void: _on_target_selected(weapon_type))
		type_row.add_child(button)

	_compare_column = VBoxContainer.new()
	_compare_column.add_theme_constant_override("separation", 6)
	column.add_child(_compare_column)

	return panel


## 右下「全部角色」區塊:最後一塊,不需要分隔線,任何角色都能轉職,不像原本設計那樣過濾
## 武器類型。
func _build_picker_panel() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.transparent_panel_style())

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	var title := Label.new()
	title.text = "全部角色"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	column.add_child(title)

	_select_bar = CharacterSelectBar.new()
	_select_bar.character_selected.connect(_on_character_selected)
	column.add_child(_select_bar)

	return panel


## 變更武器畫面唯一入口。on_close 簽名 func() -> void,「確認變更」套用完畢後呼叫,交給
## 呼叫端關閉 ActionPanel 並重開鐵匠鋪面板(見 base_action_panel.gd 的
## _open_weapon_equip_panel())。
func setup(on_close: Callable) -> void:
	_on_close = on_close

	var roster := CharacterRosterStore.all_characteres
	_select_bar.setup(roster, _build_user_card, -1, true)
	if not roster.is_empty():
		_character = roster[0]
		_select_bar.set_selected(_character)
		_detail_view.set_character(_character)

	_rebuild_compare_column()


func _build_user_card(character: Character) -> Control:
	return CharacterAvatarCard.new(character)


func _on_character_selected(character: Character) -> void:
	_character = character
	_detail_view.set_character(character)
	_rebuild_compare_column()
	_update_confirm_button()


func _on_target_selected(weapon_type: int) -> void:
	_target_type = weapon_type
	_rebuild_compare_column()
	_update_confirm_button()


func _update_confirm_button() -> void:
	_confirm_button.disabled = _character == null or _target_type == -1 or (_character != null and _target_type == _character.weapon)


func _rebuild_compare_column() -> void:
	for child in _compare_column.get_children():
		child.queue_free()

	if _character == null or _target_type == -1:
		return

	var current: WeaponInstance = WeaponStore.get_equipped(_character.weapon)
	var target: WeaponInstance = WeaponStore.get_equipped(_target_type)

	var header := Label.new()
	header.text = "%s（%s級）→ %s（%s級）" % [
		GameEnums.weapon_label(_character.weapon), GameEnums.rank_label(current.rank_type),
		GameEnums.weapon_label(_target_type), GameEnums.rank_label(target.rank_type),
	]
	header.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	_compare_column.add_child(header)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 4)
	for header_text in ["素質", "目前", "變更後", "差異"]:
		var cell := Label.new()
		cell.text = header_text
		cell.add_theme_color_override("font_color", UiStyle.PARCHMENT_SUBTITLE_COLOR)
		grid.add_child(cell)

	for potential_type in GameEnums.PotentialType.values():
		_add_compare_row(grid, potential_type, current, target)
	_compare_column.add_child(grid)


func _add_compare_row(grid: GridContainer, potential_type: int, current: WeaponInstance, target: WeaponInstance) -> void:
	var old_value := current.get_point(potential_type)
	var new_value := target.get_point(potential_type)
	var delta := new_value - old_value

	var name_label := Label.new()
	name_label.text = GameEnums.potential_label(potential_type)
	name_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	grid.add_child(name_label)

	var old_label := Label.new()
	old_label.text = str(old_value)
	old_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	grid.add_child(old_label)

	var new_label := Label.new()
	new_label.text = str(new_value)
	new_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	grid.add_child(new_label)

	var delta_label := Label.new()
	var delta_color := UiStyle.PARCHMENT_SUBTITLE_COLOR
	if delta > 0:
		delta_label.text = "+%d" % delta
		delta_color = _POSITIVE_COLOR
	elif delta < 0:
		delta_label.text = "%d" % delta
		delta_color = _NEGATIVE_COLOR
	else:
		delta_label.text = "-"
	delta_label.add_theme_color_override("font_color", delta_color)
	grid.add_child(delta_label)


func _on_confirm_pressed() -> void:
	WeaponLibrary.change_weapon_type(_character, _target_type)
	_on_close.call()
