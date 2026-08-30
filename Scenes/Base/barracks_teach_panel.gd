class_name BarracksTeachPanel
extends HBoxContainer

# =========================================================
# 兵營「傳授」獨立畫面(ActionPanel.open_custom() 開的全新內容,見 barracks_panel.gd
# 的 _open_teach_panel())。左側 CharacterDetailView 顯示目前聚焦角色;右側上方是師父/
# 學生兩個槽位 + 師父技能格,跟角色清單同一頁(不再彈 CharacterSelectOverlay 開新頁選人)
# ——槽位本身是按鈕,點下去把這格標記成「目前要指定的是師父還是學生」(_pick_target)並釋放
# 這格原本指定的人(把角色「放下來」,騰出來重選);真正選人動作在右下角的 CharacterSelectBar
# 完成,點卡片直接填進目前的目標槽位。這是先點槽位再點角色清單,不是反過來(比照玩家回饋:
# 「先點角色再點格子」不直覺,見 CLAUDE.md 這次需求)。開頁面當下不預設指定師父,只是讓左側
# CharacterDetailView 預覽名單第一位角色,師父/學生欄位維持空白。
#
# 師父/學生槽位 + 技能格三者排在同一列(justify-content: center),技能格樣式沿用
# CharacterDetailView 的 SKILL_SLOT_* 常數,跟角色詳情頁「技能」分頁的格子長相一致。不能
# 傳授的技能逐條列出卡住的原因(BarracksTeachingRule.teach_block_reasons()),不是一句話
# 概括帶過。傳授成功後師父/學生槽位維持選定,留在這一頁(不切回上一頁),方便連續傳授
# 同一組師徒多支技能。
# =========================================================

enum PickTarget { MASTER, STUDENT }

const SLOT_SIZE := Vector2(96, 96)
## 「目前作用中槽位」的邊框色——不用 UiStyle.PARCHMENT_SELECTED_BORDER(金黃色),那個顏色
## 在羊皮紙底上已經很搶眼,拿來標記「作用中」容易跟其他地方的「已選定/確認」語意混淆,
## 改用藍色系區隔。
const ACTIVE_TARGET_BORDER := Color(0.35, 0.55, 0.85, 1)

var _building: Building
var _master: Character = null
var _student: Character = null
var _selected_skill: Skill = null
var _pick_target: int = PickTarget.MASTER

var _detail_view: CharacterDetailView
var _top_area: VBoxContainer
var _picker_label: Label
var _select_bar: CharacterSelectBar
var _confirm_button: Button


func setup(building: Building) -> void:
	_building = building
	_rebuild_all()


func _ready() -> void:
	add_theme_constant_override("separation", 16)
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var detail_panel := PanelContainer.new()
	detail_panel.add_theme_stylebox_override("panel", UiStyle.right_border_style())
	add_child(detail_panel)

	_detail_view = CharacterDetailView.new()
	_detail_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_view.scrollable_tabs = false
	detail_panel.add_child(_detail_view)

	var right_column := VBoxContainer.new()
	right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_column.add_theme_constant_override("separation", 16)
	add_child(right_column)

	var top_panel := PanelContainer.new()
	top_panel.add_theme_stylebox_override("panel", UiStyle.bottom_border_style())
	right_column.add_child(top_panel)

	_top_area = VBoxContainer.new()
	_top_area.add_theme_constant_override("separation", 12)
	top_panel.add_child(_top_area)

	var picker_panel := PanelContainer.new()
	picker_panel.add_theme_stylebox_override("panel", UiStyle.transparent_panel_style())
	picker_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_column.add_child(picker_panel)

	var picker_column := VBoxContainer.new()
	picker_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	picker_column.add_theme_constant_override("separation", 10)
	picker_panel.add_child(picker_column)

	_picker_label = Label.new()
	_picker_label.add_theme_font_size_override("font_size", 18)
	_picker_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	picker_column.add_child(_picker_label)

	_select_bar = CharacterSelectBar.new()
	picker_column.add_child(_select_bar)
	_select_bar.character_selected.connect(_on_list_card_selected)
	_select_bar.setup(_roster_for_target(), _avatar_card, -1, false)

	_confirm_button = Button.new()
	_confirm_button.text = "傳授"
	UiStyle.style_panel_action_button(_confirm_button)
	_confirm_button.pressed.connect(_on_teach_pressed)
	ActionPanel.set_title_action_button(_confirm_button)

	_preview_default()


## 開頁/傳授完成後,只是讓左側 CharacterDetailView 顯示目前候選池第一位角色,不指定成師父
## ——師父/學生要玩家自己點槽位、點角色清單指定(見 CLAUDE.md 這次需求)。
func _preview_default() -> void:
	var roster := _roster_for_target()
	if not roster.is_empty():
		_detail_view.set_character(roster[0])


func _rebuild_all() -> void:
	_rebuild_top_area()
	_picker_label.text = "選擇%s（點下方角色卡指定）：" % ("師父" if _pick_target == PickTarget.MASTER else "學生")
	_select_bar.setup(_roster_for_target(), _avatar_card, -1, false)
	_select_bar.set_selected(_master if _pick_target == PickTarget.MASTER else _student)


func _rebuild_top_area() -> void:
	for child in _top_area.get_children():
		child.queue_free()

	var rank_cap := BaseBuildingProgressStore.get_rank(_building.type)
	var teach_count_text := "師父傳授次數：%d 次" % _master.taught_skill_count if _master != null else "師父傳授次數：（尚未選定師父）"
	var cap_label := Label.new()
	cap_label.text = "可傳授最高 Rank：%s｜%s" % [GameEnums.rank_label(rank_cap), teach_count_text]
	cap_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	_top_area.add_child(cap_label)

	var main_row := HBoxContainer.new()
	main_row.alignment = BoxContainer.ALIGNMENT_CENTER
	main_row.add_theme_constant_override("separation", 32)
	_top_area.add_child(main_row)

	main_row.add_child(_build_person_slot("師父", _master, PickTarget.MASTER))
	main_row.add_child(_build_person_slot("學生", _student, PickTarget.STUDENT))
	main_row.add_child(_build_skill_area(rank_cap))
	main_row.add_child(_build_student_skill_area())

	_confirm_button.disabled = _master == null or _student == null or _selected_skill == null


func _build_skill_area(rank_cap: int) -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)

	var skill_label := Label.new()
	skill_label.text = "師父的技能："
	skill_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	column.add_child(skill_label)

	if _master == null or _student == null:
		column.add_child(_build_hint_label("請先選定師父與學生"))
		return column

	if _master.skill_list.is_empty():
		column.add_child(_build_hint_label("師父目前沒有已學會的技能"))
		return column

	var grid := GridContainer.new()
	grid.columns = CharacterDetailView.SKILL_GRID_COLUMNS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for skill in _master.skill_list:
		grid.add_child(_build_skill_frame(skill, rank_cap))
	column.add_child(grid)

	return column


## 學生已學會的技能——純顯示(懸停看說明),不能點選,只是讓玩家傳授前先看一眼學生目前
## 學了什麼,避免選到學生已經會的技能(見 CLAUDE.md 這次需求)。
func _build_student_skill_area() -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)

	var skill_label := Label.new()
	skill_label.text = "學生的技能："
	skill_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	column.add_child(skill_label)

	if _student == null:
		column.add_child(_build_hint_label("請先選定學生"))
		return column

	if _student.skill_list.is_empty():
		column.add_child(_build_hint_label("學生目前沒有已學會的技能"))
		return column

	var grid := GridContainer.new()
	grid.columns = CharacterDetailView.SKILL_GRID_COLUMNS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for skill in _student.skill_list:
		grid.add_child(_build_readonly_skill_frame(skill))
	column.add_child(grid)

	return column


## 純顯示用技能格,樣式沿用 SKILL_SLOT_* 常數但固定用預設邊框(不會被選取變色),不接
## gui_input——跟 _build_skill_frame() 的差別只在「不能點」。
func _build_readonly_skill_frame(skill: Skill) -> Control:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = CharacterDetailView.SKILL_SLOT_MIN_SIZE
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.add_theme_stylebox_override("panel", UiStyle.bordered_panel(
		CharacterDetailView.SKILL_SLOT_BG, CharacterDetailView.SKILL_SLOT_BORDER, 2, 6
	))

	var label := Label.new()
	label.text = "[%s] %s" % [GameEnums.rank_label(SkillRankRule.effective_rank(skill)), skill.name]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_font_size_override("font_size", 13)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(label)

	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.tooltip_text = "【%s】\n%s" % [skill.tag_label(), skill.description]

	return slot


func _build_hint_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	return label


## 技能格樣式沿用 CharacterDetailView 的 SKILL_SLOT_* 常數,跟角色詳情頁「技能」分頁的
## 格子同一套視覺,選中時邊框換成 PARCHMENT_SELECTED_BORDER(比照卡片選中樣式)。不能傳授時
## tooltip 逐條列出卡住的原因(BarracksTeachingRule.teach_block_reasons()),不是一句話
## 概括帶過。文字不額外上色,沿用 Label 預設淺色——這格背景是深色(SKILL_SLOT_BG),跟外層
## 淺色羊皮紙底相反,套 PARCHMENT_TEXT_COLOR(深咖啡)會看不清楚。
func _build_skill_frame(skill: Skill, rank_cap: int) -> Control:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = CharacterDetailView.SKILL_SLOT_MIN_SIZE
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var is_selected := skill == _selected_skill
	var border_color := UiStyle.PARCHMENT_SELECTED_BORDER if is_selected else CharacterDetailView.SKILL_SLOT_BORDER
	var border_width := 3 if is_selected else 2
	slot.add_theme_stylebox_override("panel", UiStyle.bordered_panel(
		CharacterDetailView.SKILL_SLOT_BG, border_color, border_width, 6
	))

	var label := Label.new()
	label.text = "[%s] %s" % [GameEnums.rank_label(SkillRankRule.effective_rank(skill)), skill.name]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_font_size_override("font_size", 13)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(label)

	var reasons := BarracksTeachingRule.teach_block_reasons(_master, _student, skill, rank_cap)
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	if reasons.is_empty():
		slot.modulate = CharacterDetailView.SKILL_ENABLED_MODULATE
		slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		slot.tooltip_text = "【%s】\n%s" % [skill.tag_label(), skill.description]
		slot.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_selected_skill = skill
				_rebuild_all()
		)
	else:
		slot.modulate = CharacterDetailView.SKILL_DISABLED_MODULATE
		slot.tooltip_text = "無法傳授：\n%s" % "\n".join(reasons)

	return slot


## 空槽顯示「點擊選擇」;已選顯示頭像 + 姓名。點擊這格會把 _pick_target 切到這一格,並且
## 「放下」這格原本指定的人(清空回未指定,騰出來讓玩家用下方角色清單重選)——不用先在清單
## 點角色再回頭點槽位,是槽位先決定「現在要選誰」(見 CLAUDE.md 這次需求)。目前作用中的
## 目標槽位邊框高亮。
func _build_person_slot(caption_text: String, character: Character, target: int) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.alignment = BoxContainer.ALIGNMENT_CENTER

	var is_active := _pick_target == target
	var caption := Label.new()
	caption.text = caption_text
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	box.add_child(caption)

	var slot := PanelContainer.new()
	slot.custom_minimum_size = SLOT_SIZE
	# 不設 EXPAND_FILL——旁邊的姓名列文字較長時會把 box 撐寬,slot 預設的 SIZE_FILL 會
	# 跟著被拉寬,頭像圖片因此被橫向拉伸變形。鎖成 SHRINK_CENTER 讓 slot 永遠維持
	# SLOT_SIZE 正方形,只在 box 裡置中,不會被撐寬。
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# content_margin 留一圈空隙——頭像 TextureRect 跟 slot 同尺寸(SLOT_SIZE)貼滿整個
	# PanelContainer,margin=0 的話邊框會被頭像整個蓋住看不見(選了角色後就看不出目前
	# ACTIVE 是哪一格),留白讓邊框露在頭像外側。
	var border_color := ACTIVE_TARGET_BORDER if is_active else UiStyle.PARCHMENT_ROW_BORDER
	slot.add_theme_stylebox_override("panel", UiStyle.parchment_row_style(border_color, 3 if is_active else 1, 8, 4.0, 4.0, 0))
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	slot.tooltip_text = "點擊放開並改選%s" % caption_text if character != null else "點擊切換為選擇%s" % caption_text

	if character == null:
		var placeholder := Label.new()
		placeholder.text = "點擊選擇"
		placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		placeholder.autowrap_mode = TextServer.AUTOWRAP_WORD
		placeholder.custom_minimum_size = SLOT_SIZE
		placeholder.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
		slot.add_child(placeholder)
	else:
		var face := TextureRect.new()
		face.custom_minimum_size = SLOT_SIZE
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_SCALE
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not character.face_path.is_empty():
			face.texture = load(character.face_path) as Texture2D
		slot.add_child(face)

	slot.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if target == PickTarget.MASTER:
				_master = null
			else:
				_student = null
			_pick_target = target
			_selected_skill = null
			_rebuild_all()
	)
	box.add_child(slot)

	var name_label := Label.new()
	name_label.text = character.display_name if character != null else ""
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	box.add_child(name_label)

	return box


## 目前選擇目標(師父/學生)決定角色清單候選池:師父池排除目前選定的學生,學生池排除
## 目前選定的師父。
func _roster_for_target() -> Array[Character]:
	var characters: Array[Character] = []
	for character in CharacterRosterStore.all_characteres:
		if character.is_disabled:
			continue
		if _pick_target == PickTarget.MASTER:
			if character == _student:
				continue
		else:
			if character == _master:
				continue
		characters.append(character)
	return characters


func _on_list_card_selected(character: Character) -> void:
	if _pick_target == PickTarget.MASTER:
		_master = character
	else:
		_student = character
	_selected_skill = null
	_detail_view.set_character(character)
	_rebuild_all()


## 傳授成功留在這一頁(不切回上一頁),師父/學生槽位維持選定不清空,方便連續傳授同一組
## 師徒多支技能(見 CLAUDE.md 這次需求)。放棄學習不算真的傳授,同樣留在原地讓玩家重選。
func _on_teach_pressed() -> void:
	var master := _master
	var student := _student
	var skill := _selected_skill
	SkillLearnFlow.try_learn(student, skill, func(applied: bool) -> void:
		if applied:
			master.taught_skill_count += 1
			NewsController.post("%s 拜 %s 為師，習得「%s」。" % [student.display_name, master.display_name, skill.name], GameEnums.NewsCategory.DAILY)
		_selected_skill = null
		_rebuild_all()
	)


func _avatar_card(character: Character) -> Control:
	return CharacterAvatarCard.new(character)
