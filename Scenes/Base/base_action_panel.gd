class_name BaseBuildingPanelContent
extends VBoxContainer

## 根據地建築面板的「內容」——不是獨立的彈出面板,外殼(背景遮罩/Margin/離開鈕位置/
## 面板大小)一律共用 Scenes/ActionPanel/action_panel.gd 的 open_custom(),跟酒館招募
## 清單那個彈窗長相一致,只有這塊內容區塊依事件/情況不同換掉(見
## System/event/base/base_building_event.gd 的 _open_action_panel())。
##
## 依 BaseBuildingProgressStore 的狀態分支顯示:0 級未建造顯示「建造」按鈕;建造中顯示
## 倒數天數;已建成顯示等級/升級(升級中不影響下面的產出/派遣顯示,建築正常運作);
## 生產類建築額外顯示目前月產量與工作角色頭像格(容量=等級,點空格開角色清單指派、
## 點已填格子直接召回);非生產類建築維持「尚未實作」。角色清單顯示全部未禁用角色,
## 已在此工作/在別處工作的人反灰純顯示,整卡點擊指派只對可選的人生效,卡片上的小頭像
## 另外接一個獨立點擊區開 CharacterPanel(靠子節點 MOUSE_FILTER_STOP 先吃掉事件擋掉
## 冒泡,同 Scenes/Battle/battle_party_roster.gd 頭像框的寫法)。

const AVATAR_SLOT_SIZE := Vector2(56, 56)
const PICKER_FACE_SIZE := Vector2(64, 64)

var _building: Building
## 是否正在展開「選一位角色派遣」清單,指派/取消後歸零。
var _picking_character: bool = false
## 升級/建造失敗(資材不足)後單次顯示一行提示,顯示完就消耗掉,不跨 rebuild 保留。
var _upgrade_error: bool = false
var _build_error: bool = false


func _init(p_building: Building) -> void:
	_building = p_building


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	_rebuild_body()


func _rebuild_body() -> void:
	for child in get_children():
		child.queue_free()

	_add_label(_building.description)

	if BaseBuildingProgressStore.is_constructing(_building.type):
		_add_label("建造中,%d 天後完工" % BaseBuildingProgressStore.get_construction_days_remaining(_building.type))
		return

	if not BaseBuildingProgressStore.is_unlocked(_building.type):
		_build_build_section()
		return

	_build_level_section()

	if not _building.is_production_building():
		_add_label("尚未實作")
		return

	if _picking_character:
		_build_character_picker()
		return

	_build_efficiency_label()
	_build_worker_slots()


func _build_build_section() -> void:
	var button := Button.new()
	button.text = "建造（耗材：%s，天數：%d 天）" % [_format_cost(_building.build_cost), _building.build_days]
	button.pressed.connect(func() -> void:
		_build_error = not BaseBuildingProgressStore.start_construction(_building)
		_rebuild_body()
	)
	add_child(button)
	if _build_error:
		_add_label("資材不足")
		_build_error = false


func _build_level_section() -> void:
	var level := BaseBuildingProgressStore.get_level(_building.type)
	_add_label("等級：%s" % GameEnums.rank_label(BaseBuildingProgressStore.get_rank(_building.type)))

	if BaseBuildingProgressStore.is_upgrading(_building.type):
		_add_label("升級中,%d 天後完成" % BaseBuildingProgressStore.get_upgrade_days_remaining(_building.type))
	elif BaseBuildingProgressStore.can_upgrade(_building):
		var cost := BaseBuildingProgressStore.get_upgrade_cost(_building)
		var days := BaseBuildingProgressStore.get_upgrade_days(_building)
		var upgrade_button := Button.new()
		upgrade_button.text = "升級至 %s 級（耗材：%s，天數：%d 天）" % [GameEnums.rank_label(level), _format_cost(cost), days]
		upgrade_button.pressed.connect(func() -> void:
			_upgrade_error = not BaseBuildingProgressStore.start_upgrade(_building)
			_rebuild_body()
		)
		add_child(upgrade_button)
		if _upgrade_error:
			_add_label("資材不足")
			_upgrade_error = false
	else:
		_add_label("已達最高等級")


func _build_efficiency_label() -> void:
	var characters := BaseDispatchStore.get_dispatched_characters(_building.type)
	var rank := BaseBuildingProgressStore.get_rank(_building.type)
	var monthly_yield := BaseProduction.compute_monthly_yield(_building, characters, rank)
	_add_label("目前效率：%d %s/月" % [monthly_yield, GameEnums.resource_type_label(_building.produces)])


func _build_worker_slots() -> void:
	_add_label("工作角色：")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)

	var dispatched := BaseDispatchStore.get_dispatched_characters(_building.type)
	for i in range(BaseBuildingProgressStore.get_max_workers(_building.type)):
		var character: Character = dispatched[i] if i < dispatched.size() else null
		row.add_child(_build_worker_slot(character))


## 已填的格子放頭像,點擊直接召回;空格子點擊展開下方的角色清單(_picking_character)。
func _build_worker_slot(character: Character) -> Control:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = AVATAR_SLOT_SIZE
	slot.add_theme_stylebox_override("panel", UiStyle.parchment_row_style(UiStyle.PARCHMENT_ROW_BORDER, 1, 8, 0.0, 0.0, 0))
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	if character != null:
		var face := TextureRect.new()
		face.custom_minimum_size = AVATAR_SLOT_SIZE
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_SCALE
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not character.face_path.is_empty():
			face.texture = load(character.face_path) as Texture2D
		slot.add_child(face)
		slot.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				BaseDispatchStore.undispatch(_building.type, character.id)
				_rebuild_body()
		)
	else:
		slot.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_picking_character = true
				_rebuild_body()
		)

	return slot


## 顯示全部未禁用角色(不只是可指派的人)——已在此工作/在別處工作的人一樣列出來,
## 靠反灰純視覺區分,召回改到 _build_worker_slot() 那邊點頭像格處理。
func _build_character_picker() -> void:
	var characters: Array[Character] = []
	for character in CharacterRosterStore.all_characteres:
		if not character.is_disabled:
			characters.append(character)

	if characters.is_empty():
		_add_label("沒有角色")

	for character in characters:
		add_child(_build_character_row(character))

	var cancel_button := Button.new()
	cancel_button.text = "取消"
	cancel_button.pressed.connect(func() -> void:
		_picking_character = false
		_rebuild_body()
	)
	add_child(cancel_button)


## 整卡點擊 = 指派(只對可選的人接線,反灰的人點了沒反應);卡片上的小頭像另外包一層
## MOUSE_FILTER_STOP + 自己的 gui_input,靠子節點優先吃到輸入事件擋掉往外層卡片冒泡,
## 所有人(含反灰)都能點頭像開 CharacterPanel 看詳情,跟 battle_party_roster.gd 頭像框
## 同一套技巧。
func _build_character_row(character: Character) -> Control:
	var is_here := BaseDispatchStore.get_dispatched_character_ids(_building.type).has(character.id)
	var is_elsewhere := not is_here and BaseDispatchStore.is_character_dispatched(character.id)
	var assignable := not is_here and not is_elsewhere

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiStyle.parchment_row_style(UiStyle.PARCHMENT_ROW_BORDER, 1, 8, 10.0, 6.0))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	if not assignable:
		card.modulate.a = 0.45
	else:
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				var success := BaseDispatchStore.dispatch(_building.type, character.id)
				_picking_character = false
				_rebuild_body()
				if not success:
					_add_label("已滿額")
		)

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	card.add_child(content)

	var face_wrapper := CenterContainer.new()
	face_wrapper.mouse_filter = Control.MOUSE_FILTER_STOP
	face_wrapper.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	face_wrapper.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			CharacterPanel.open_for_character(character)
			get_viewport().set_input_as_handled()
	)
	content.add_child(face_wrapper)

	var face := TextureRect.new()
	face.custom_minimum_size = PICKER_FACE_SIZE
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_SCALE
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not character.face_path.is_empty():
		face.texture = load(character.face_path) as Texture2D
	face_wrapper.add_child(face)

	var info_column := VBoxContainer.new()
	info_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(info_column)

	var name_label := Label.new()
	name_label.text = character.full_name
	name_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	info_column.add_child(name_label)

	if is_here or is_elsewhere:
		var status_label := Label.new()
		status_label.text = "在此工作" if is_here else "在其他地方工作"
		status_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_SUBTITLE_COLOR)
		info_column.add_child(status_label)

	var potential_grid := GridContainer.new()
	potential_grid.columns = 2
	potential_grid.add_theme_constant_override("h_separation", 16)
	potential_grid.add_theme_constant_override("v_separation", 2)
	info_column.add_child(potential_grid)

	# 排列順序跟 CharacterDetailView.POTENTIAL_GRID_ORDER 共用,同一套「力量/敏捷、
	# 體質/靈巧、智慧/信仰」慣例。
	for potential_type in CharacterDetailView.POTENTIAL_GRID_ORDER:
		var stat_label := Label.new()
		stat_label.text = "%s %d" % [GameEnums.potential_label(potential_type), roundi(character.get_potential(potential_type))]
		stat_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_SUBTITLE_COLOR)
		potential_grid.add_child(stat_label)

	return card


func _format_cost(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for resource_type in cost:
		parts.append("%s x%d" % [GameEnums.resource_type_label(resource_type), cost[resource_type]])
	return "、".join(parts)


func _add_label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	add_child(label)
