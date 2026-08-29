class_name BarracksLeaderTrainingPanel
extends HBoxContainer

# =========================================================
# 兵營「隊長訓練」獨立畫面(ActionPanel.open_custom() 開的全新內容,見 barracks_panel.gd
# 的 _open_leader_training_panel())。左側 CharacterDetailView,右側上方是可學的隊長技能
# (SkillLibraryLeader 全部 18 支,不限定角色是否為現任隊長——隊長技能誰都能學,只有戰鬥中
# BattleCharacter.is_leader 才會被納入行動候選,這裡不重複擋),右下角是角色清單
# (CharacterSelectBar,跟角色選擇同一頁,不再另開 CharacterSelectOverlay),點卡片直接
# 切換目前訓練對象。開頁當下預設選第一位角色,CharacterDetailView 不會空著。技能格樣式
# 沿用 CharacterDetailView 的 SKILL_SLOT_* 常數,跟角色詳情頁「技能」分頁一致。
# =========================================================

var _building: Building
var _character: Character = null
var _selected_skill: Skill = null
## 開頁時建一次,之後重繪都重用同一批 Skill 實例——SkillLibrary.build() 每次呼叫都會
## new 出全新物件,若每次 _rebuild_function() 重新 build() 一次,_selected_skill 存的
## 舊實例會跟新列表裡的物件不是同一個參照,skill == _selected_skill 永遠比對不出來,
## 選中的技能格邊框就變不了黃色(比照 BarracksTeachPanel 用 master.skill_list 固定
## 陣列的作法)。
var _leader_skills: Array[Skill] = []

var _detail_view: CharacterDetailView
var _function_column: VBoxContainer
var _select_bar: CharacterSelectBar
var _confirm_button: Button


func setup(building: Building) -> void:
	_building = building
	_rebuild_function()


func _ready() -> void:
	add_theme_constant_override("separation", 16)
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	for skill in SkillLibrary.build():
		if skill.is_leader_skill:
			_leader_skills.append(skill)
	_leader_skills.sort_custom(func(a: Skill, b: Skill) -> bool: return a.rank < b.rank)

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

	_function_column = VBoxContainer.new()
	_function_column.add_theme_constant_override("separation", 10)
	top_panel.add_child(_function_column)

	var picker_panel := PanelContainer.new()
	picker_panel.add_theme_stylebox_override("panel", UiStyle.transparent_panel_style())
	picker_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_column.add_child(picker_panel)

	var picker_column := VBoxContainer.new()
	picker_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	picker_column.add_theme_constant_override("separation", 10)
	picker_panel.add_child(picker_column)

	var picker_title := Label.new()
	picker_title.text = "全部角色"
	picker_title.add_theme_font_size_override("font_size", 18)
	picker_title.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	picker_column.add_child(picker_title)

	_select_bar = CharacterSelectBar.new()
	picker_column.add_child(_select_bar)

	var roster: Array[Character] = []
	for character in CharacterRosterStore.all_characteres:
		if not character.is_disabled:
			roster.append(character)
	if not roster.is_empty():
		_character = roster[0]
		_detail_view.set_character(_character)

	_select_bar.character_selected.connect(_on_list_card_selected)
	_select_bar.setup(roster, _avatar_card, -1, false)
	_select_bar.set_selected(_character)

	_confirm_button = Button.new()
	_confirm_button.text = "訓練"
	UiStyle.style_panel_action_button(_confirm_button)
	_confirm_button.pressed.connect(_on_train_pressed)
	ActionPanel.set_title_action_button(_confirm_button)


func _rebuild_function() -> void:
	for child in _function_column.get_children():
		child.queue_free()

	var gold_label := RichTextLabel.new()
	gold_label.bbcode_enabled = true
	gold_label.fit_content = true
	gold_label.scroll_active = false
	gold_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	gold_label.add_theme_color_override("default_color", UiStyle.PARCHMENT_TEXT_COLOR)
	gold_label.text = "目前金錢：%s%d" % [
		"[img=20x20]%s[/img] " % GameEnums.resource_type_icon_path(GameEnums.ResourceType.GOLD),
		BaseResourceStore.get_display_amount(GameEnums.ResourceType.GOLD)
	]
	_function_column.add_child(gold_label)

	var rank_cap := BaseBuildingProgressStore.get_rank(_building.type)
	var cap_label := Label.new()
	cap_label.text = "可訓練最高 Rank：%s" % GameEnums.rank_label(rank_cap)
	cap_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	_function_column.add_child(cap_label)

	var skill_label := Label.new()
	skill_label.text = "可學技能："
	skill_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	_function_column.add_child(skill_label)

	# HFlowContainer:每個技能格維持固定寬度(跟 CharacterDetailView 的技能格一樣寬),
	# 由左到右自動排列、一行放不下自動換到下一行(inline-block 效果),不是寫死一欄一個
	# 或固定兩欄(見 CLAUDE.md 這次需求)。
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	for skill in _leader_skills:
		flow.add_child(_build_skill_frame(skill, rank_cap))
	_function_column.add_child(flow)

	var cost := LeaderTrainingRule.cost_for_skill(_selected_skill) if _selected_skill != null else 0
	_confirm_button.disabled = (
		_character == null or _selected_skill == null
		or not BaseResourceStore.can_afford({GameEnums.ResourceType.GOLD: cost})
	)


## 技能格樣式沿用 CharacterDetailView 的 SKILL_SLOT_* 常數,跟角色詳情頁「技能」分頁的
## 格子同一套視覺,選中時邊框換成 PARCHMENT_SELECTED_BORDER(比照卡片選中樣式)。放進
## HFlowContainer 裡不用特別設 size_flags——flow container 本來就照子節點各自的最小尺寸
## 由左到右排,不會互相撐寬。
func _build_skill_frame(skill: Skill, rank_cap: int) -> Control:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = CharacterDetailView.SKILL_SLOT_MIN_SIZE

	var is_selected := skill == _selected_skill
	var border_color := UiStyle.PARCHMENT_SELECTED_BORDER if is_selected else CharacterDetailView.SKILL_SLOT_BORDER
	var border_width := 3 if is_selected else 2
	slot.add_theme_stylebox_override("panel", UiStyle.bordered_panel(
		CharacterDetailView.SKILL_SLOT_BG, border_color, border_width, 6
	))

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(center)

	var cost := LeaderTrainingRule.cost_for_skill(skill)
	var icon_tag := "[img=14x14]%s[/img]" % GameEnums.resource_type_icon_path(GameEnums.ResourceType.GOLD)
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.custom_minimum_size = Vector2(CharacterDetailView.SKILL_SLOT_MIN_SIZE.x - 12.0, 0)
	label.add_theme_font_size_override("normal_font_size", 13)
	# 技能格背景是 CharacterDetailView.SKILL_SLOT_BG(深色),不是外層的淺色羊皮紙底——
	# 這裡沿用跟角色詳情頁技能格同款的深底,文字要用白色/淺色才看得清楚,不能套外層羊皮紙
	# 面板慣用的深咖啡 PARCHMENT_TEXT_COLOR(那是給淺色底配的,見 CLAUDE.md 這次需求)。
	label.add_theme_color_override("default_color", Color(1, 1, 1, 1))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = "[center][%s] %s\n%s %d[/center]" % [
		GameEnums.rank_label(SkillRankRule.effective_rank(skill)), skill.name, icon_tag, cost
	]
	center.add_child(label)

	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	if _character == null:
		slot.modulate = CharacterDetailView.SKILL_DISABLED_MODULATE
		slot.tooltip_text = "請先選擇角色"
	else:
		var can_learn := LeaderTrainingRule.can_learn(_character, skill, rank_cap)
		slot.modulate = CharacterDetailView.SKILL_ENABLED_MODULATE if can_learn else CharacterDetailView.SKILL_DISABLED_MODULATE
		if can_learn:
			slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			slot.tooltip_text = "【%s】\n%s" % [skill.tag_label(), skill.description]
			slot.gui_input.connect(func(event: InputEvent) -> void:
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					_selected_skill = skill
					_rebuild_function()
			)
		else:
			slot.tooltip_text = "無法訓練：已學會此技能，或兵營等級不足"

	return slot


func _on_list_card_selected(character: Character) -> void:
	_character = character
	_selected_skill = null
	_detail_view.set_character(character)
	_select_bar.set_selected(character)
	_rebuild_function()


## 訓練成功留在這一頁繼續選(不切回主頁),但要主動重繪左側 CharacterDetailView——不然
## 畫面看起來像「按了訓練但沒反應」,玩家會以為沒學到(見 CLAUDE.md 這次需求)。選定的
## 角色維持不變,方便連續訓練同一人;放棄學習(SkillReplaceDialog 選放棄)一樣留在原地
## 讓玩家重選。
func _on_train_pressed() -> void:
	var character := _character
	var skill := _selected_skill
	var cost := LeaderTrainingRule.cost_for_skill(skill)
	SkillLearnFlow.try_learn(character, skill, func(applied: bool) -> void:
		if applied:
			BaseResourceStore.spend({GameEnums.ResourceType.GOLD: cost})
			_detail_view.set_character(character)
		_selected_skill = null
		_rebuild_function()
	)


func _avatar_card(character: Character) -> Control:
	return CharacterAvatarCard.new(character)
