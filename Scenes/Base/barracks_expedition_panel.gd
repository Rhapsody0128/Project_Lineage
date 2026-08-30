class_name BarracksExpeditionPanel
extends HBoxContainer

# =========================================================
# 兵營「歷練」獨立畫面(ActionPanel.open_custom() 開的全新內容,見 barracks_panel.gd 的
# _open_expedition_panel())。版面比照 Scenes/Base/worker_dispatch_panel.gd(左側角色詳情/
# 右上名額格/右下角色清單,點清單卡片即時派遣),但這裡不用再包一層 CharacterSelectOverlay
# ——整個面板本身已經是 ActionPanel.open_custom() 開的獨立畫面,不像 WorkerDispatchPanel
# 是從別的已開啟 ActionPanel 內容裡再疊一層。
#
# 名額格三態(WorkerDispatchPanel 只有空/已指派兩態):空格純視覺佔位;歷練中顯示「剩 N
# 天」,點擊臨時召回(無獎勵,ConfirmDialog 二次確認);已歸來待確認顯示「待確認」(邊框
# 變色跟前兩態區隔),點擊直接觸發收成流程,不需要二次確認。
#
# 收成要串 SkillLearnFlow(一次可能有 1~2 個技能,技能滿 4 個要跳 SkillReplaceDialog,
# 可能連續彈好幾次)——BarracksExpeditionStore.collect() 已拆成 get_completed_skills()
# (唯讀)/finalize_collect()(發經驗+清紀錄),技能學習流程跑完才呼叫 finalize_collect()。
# =========================================================

const AVATAR_SLOT_SIZE := Vector2(64, 64)

var _building: Building
var _detail_view: CharacterDetailView
var _slots_row: HBoxContainer
var _select_bar: CharacterSelectBar


func _init(p_building: Building) -> void:
	_building = p_building


func _ready() -> void:
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

	right_column.add_child(_build_slots_panel())
	right_column.add_child(_build_picker_panel())

	var roster: Array[Character] = []
	for character in CharacterRosterStore.all_characteres:
		if not character.is_disabled:
			roster.append(character)
	if not roster.is_empty():
		_detail_view.set_character(roster[0])

	BarracksExpeditionStore.changed.connect(_on_store_changed)

	_select_bar.character_selected.connect(_on_list_card_selected)
	_select_bar.setup(roster, _make_expedition_card, -1, false)

	_rebuild_slots()


func _build_slots_panel() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.bottom_border_style())

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	var slots_label := Label.new()
	slots_label.text = "歷練名額（點頭像召回/確認歸隊）："
	slots_label.add_theme_font_size_override("font_size", 18)
	slots_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	column.add_child(slots_label)

	_slots_row = HBoxContainer.new()
	_slots_row.add_theme_constant_override("separation", 8)
	column.add_child(_slots_row)

	return panel


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
	column.add_child(_select_bar)

	return panel


func _rebuild_slots() -> void:
	for child in _slots_row.get_children():
		child.queue_free()

	var occupied_ids: Array[String] = []
	occupied_ids.append_array(BarracksExpeditionStore.get_completed_members())
	occupied_ids.append_array(BarracksExpeditionStore.get_expedition_members())

	for i in range(BarracksExpeditionStore.capacity()):
		var character_id: String = occupied_ids[i] if i < occupied_ids.size() else ""
		_slots_row.add_child(_build_slot(character_id))


func _build_slot(character_id: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)

	var slot := PanelContainer.new()
	slot.custom_minimum_size = AVATAR_SLOT_SIZE
	var is_awaiting := not character_id.is_empty() and BarracksExpeditionStore.is_awaiting_collection(character_id)
	var border_color := UiStyle.PARCHMENT_SELECTED_BORDER if is_awaiting else UiStyle.PARCHMENT_ROW_BORDER
	slot.add_theme_stylebox_override("panel", UiStyle.parchment_row_style(border_color, 1, 8, 0.0, 0.0, 0))
	box.add_child(slot)

	var status_label := Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	box.add_child(status_label)

	if character_id.is_empty():
		return box

	var character := BaseDispatchStore.find_character(character_id)
	if character == null:
		return box

	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var face := TextureRect.new()
	face.custom_minimum_size = AVATAR_SLOT_SIZE
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_SCALE
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not character.face_path.is_empty():
		face.texture = load(character.face_path) as Texture2D
	slot.add_child(face)

	if is_awaiting:
		status_label.text = "待確認"
		slot.tooltip_text = "%s：已歷練歸來，點擊確認歸隊" % character.display_name
		slot.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_on_collect_slot_clicked(character)
		)
	else:
		var days := BarracksExpeditionStore.get_days_remaining(character_id)
		status_label.text = "剩%d天" % days
		slot.tooltip_text = "%s：點擊臨時召回（無獎勵）" % character.display_name
		slot.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_on_recall_slot_clicked(character_id, character.display_name)
		)

	return box


func _on_recall_slot_clicked(character_id: String, character_name: String) -> void:
	ConfirmDialog.ask("確定要臨時召回 %s 嗎？不會有任何歷練獎勵。" % character_name, func() -> void:
		BarracksExpeditionStore.recall(character_id)
		_rebuild_slots()
		_select_bar.refresh()
	, Callable(), "確定", "取消")


func _on_collect_slot_clicked(character: Character) -> void:
	_grant_next_skill(character, BarracksExpeditionStore.get_completed_skills(character.id), 0)


func _grant_next_skill(character: Character, skills: Array[Skill], index: int) -> void:
	if index >= skills.size():
		BarracksExpeditionStore.finalize_collect(character.id)
		_rebuild_slots()
		_select_bar.refresh()
		return
	SkillLearnFlow.try_learn(character, skills[index], func(_applied: bool) -> void:
		_grant_next_skill(character, skills, index + 1)
	)


## 滿額直接不反應(比照 WorkerDispatchPanel 既有慣例,不跳提示)。已歷練中/待確認/小隊隊長
## 的卡片本身不可點(見 _make_expedition_card()),不會進到這裡;派駐其他建築的先跳確認
## (_confirm_reassign_from_job()——跟 WorkerDispatchPanel 反過來遇到歷練中角色同一套
## 「反灰但可點、點下去先問過玩家」慣例,見 CLAUDE.md 這次需求,兩邊操作要一致);已編入
## 小隊的非隊長成員可點,直接送去歷練——BarracksExpeditionStore.send() 內部會自動把它
## 移出小隊。
func _on_list_card_selected(character: Character) -> void:
	if BarracksExpeditionStore.get_expedition_members().size() >= BarracksExpeditionStore.capacity():
		return

	var dispatched_building_type := BaseDispatchStore.get_dispatched_building_type(character.id)
	if dispatched_building_type != -1:
		_confirm_reassign_from_job(character, dispatched_building_type)
		return

	_detail_view.set_character(character)
	BarracksExpeditionStore.send(character)
	_rebuild_slots()
	_select_bar.refresh()


## 「OOO 目前在XXX工作,是否改安排去歷練?」——確定才真的把人從建築召回、送去歷練
## (BarracksExpeditionStore.send() 本身會擋派駐中的角色,見該檔案,所以要先
## undispatch_character() 清掉派駐紀錄再呼叫)。
func _confirm_reassign_from_job(character: Character, building_type: int) -> void:
	var building_name := GameEnums.building_type_label(building_type)
	var message := "%s 目前在%s工作，是否改安排去歷練？" % [character.display_name, building_name]
	ConfirmDialog.ask(message, func() -> void:
		BaseDispatchStore.undispatch_character(character.id)
		_detail_view.set_character(character)
		BarracksExpeditionStore.send(character)
		_rebuild_slots()
		_select_bar.refresh()
	, Callable(), "確定", "取消")


## 已歷練中/待確認歸隊/小隊隊長不可點(反灰整個擋掉);派駐其他建築的維持可點但視覺上一樣
## 反灰(force_dim),點下去走確認流程(見 _on_list_card_selected()/
## _confirm_reassign_from_job())——跟 WorkerDispatchPanel 反過來遇到歷練中角色的處理方式
## 對稱一致(見 CLAUDE.md 這次需求)。已編入小隊的非隊長成員一樣可點但反灰,點下去直接送去
## 歷練,BarracksExpeditionStore.send() 內部會自動移出小隊。
func _make_expedition_card(character: Character) -> Control:
	var is_on_expedition := BarracksExpeditionStore.is_on_expedition(character.id)
	var is_awaiting := BarracksExpeditionStore.is_awaiting_collection(character.id)
	var dispatched_building_type := BaseDispatchStore.get_dispatched_building_type(character.id)
	var is_elsewhere := dispatched_building_type != -1
	var is_party_leader := PartyStore.party != null and PartyStore.party.leader == character
	var is_in_party := PartyStore.party != null and PartyStore.party.characteres.has(character) and not is_party_leader
	var available := not is_on_expedition and not is_awaiting and not is_party_leader
	var unavailable_reason := ""
	if is_on_expedition:
		unavailable_reason = "歷練中"
	elif is_awaiting:
		unavailable_reason = "待確認歸隊"
	elif is_party_leader:
		unavailable_reason = "小隊隊長，無法歷練"
	elif is_elsewhere:
		unavailable_reason = "在%s工作，點擊可改派來歷練" % GameEnums.building_type_label(dispatched_building_type)
	elif is_in_party:
		unavailable_reason = "已編入小隊"
	return CharacterAvatarCard.new(character, available, unavailable_reason, is_in_party or is_elsewhere)


func _on_store_changed() -> void:
	_rebuild_slots()
	_select_bar.refresh()
