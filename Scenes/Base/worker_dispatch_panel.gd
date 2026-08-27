class_name WorkerDispatchPanel
extends HBoxContainer

# =========================================================
# 根據地生產建築「指派工作角色」內容,塞進 Scenes/CharacterSelect/
# character_select_overlay.gd 的 CharacterSelectOverlay.open_content() 顯示。跟通用的
# CharacterSelectPanel(選一個、按確認)不是同一種情境——這裡選人/召回都是點下去立即生效,
# 疊加視窗開著時可以連續調整好幾個人,沒有單一「結果」可以 confirm,所以不走
# character_confirmed 那條路,呼叫端改監聽 CharacterSelectOverlay 的 tree_exiting 訊號,
# 疊加視窗關閉時才重建底下的建築面板(見 base_action_panel.gd 的 _open_dispatch_picker())。
#
# 版面三塊,比照 stronghold_marriage_panel.gd/marriage_proposal_panel.gd 的既有慣例——
# 左側固定寬度 CharacterDetailView 一塊獨立羊皮紙面板,右側上下各一塊獨立羊皮紙面板,
# 各自內容可能超出自己那個框時各自捲動(ActionPanel.wrap_scrollable()),不會互相牽連、
# 也不會把整包右側撐高變成捲動整個面板。左側初始顯示依建築適應性素質(potential_type)
# 排序最高的角色,給玩家一個「這個建築最適合誰」的預覽起點;右下角色清單點卡片時除了
# 嘗試指派,也會同步把左側焦點換成剛點的那個人(見 _on_list_card_selected()),方便玩家
# 一邊點一邊確認剛選的人素質——召回(點右上已填格子)不影響左側焦點。右上是目前已指派的
# 工作角色列(格數 = 建築等級),點已填格子立即召回。右下是全部未禁用角色清單
# (CharacterSelectBar),
# 已在此工作/小隊隊長的人反灰不能點(小隊至少要留一位隊長,見 base_dispatch_store.gd
# 的 dispatch());派駐在「別的」建築、或已編入小隊但不是隊長的人比較特殊——卡片維持可點
# 但視覺上一樣反灰(force_dim,示意非「目前沒派駐任何建築也沒編隊」的直接可指派狀態),
# 滑過去 tooltip 明確顯示原因:派駐別的建築顯示「在OOO工作」(建築名稱內插,同
# CharacterStatusRule.get_status_label() 的既有寫法,不是含糊的「在其他地方工作」),點下去
# 不會直接搶過來,而是跳 ConfirmDialog 問「OOO 目前在XXX工作,是否改安排到YYY工作?」,
# 確定才真的 undispatch 舊建築、dispatch 新建築(見 _on_list_card_selected()/
# _confirm_reassign());已編入小隊的非隊長成員點下去則直接指派,dispatch() 內部會自動把它
# 移出小隊(跟 PartyEdit 那邊允許把已派駐角色重新拖回小隊是同一組雙向轉換,不再完全互斥)。
# ConfirmDialog 是全域 autoload 通用是/否彈窗(Scenes/ConfirmDialog/confirm_dialog.gd),
# CanvasLayer.layer 已經調到蓋過這裡用的 CharacterSelectOverlay,可以直接疊上來用,不需要
# 另外做一顆專屬彈窗。已滿額時 BaseDispatchStore.dispatch() 本來就會回傳 false、什麼都不做,
# 這裡不需要另外攔一次或跳錯誤提示。
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
	add_child(detail_panel)

	_detail_view = CharacterDetailView.new()
	_detail_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.add_child(_detail_view)

	# 比照 character_select_panel.gd 的既有寫法:掛進樹裡才問得到 _detail_view 自己攜帶的
	# custom_minimum_size(CharacterDetailView.PANEL_WIDTH)。
	var panel_size := detail_panel.get_combined_minimum_size()
	UiStyle.apply_parchment_panel(detail_panel, panel_size.x, panel_size.y)

	var right_column := VBoxContainer.new()
	right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_column.add_theme_constant_override("separation", 16)
	add_child(right_column)

	right_column.add_child(_build_slots_panel())
	right_column.add_child(_build_picker_panel())

	var roster: Array[Character] = []
	for character in CharacterRosterStore.all_characteres:
		if not character.is_disabled:
			roster.append(character)

	var sort_key := 3 + _building.potential_type
	var focus_sort := CharacterSortFilter.new()
	focus_sort.sort_key = sort_key
	var focus_candidates := focus_sort.apply(roster)
	if not focus_candidates.is_empty():
		_detail_view.set_character(focus_candidates[0])

	_select_bar.character_selected.connect(_on_list_card_selected)
	_select_bar.setup(roster, _make_dispatch_card, sort_key, false)

	_rebuild_slots()


## 右上「工作角色」區塊:獨立木框羊皮紙面板,固定高度,_slots_row 包一層捲動框防呆——
## 格數多到超出面板寬度時交給捲動框自己吃掉,不會撐大整個右側欄位(見 stronghold_marriage_panel.gd
## 的 _build_nation_panel() 同一套做法)。
func _build_slots_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 160)
	UiStyle.apply_parchment_panel(panel, 700.0, 160.0)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	var slots_label := Label.new()
	slots_label.text = "工作角色（點頭像召回）："
	slots_label.add_theme_font_size_override("font_size", 18)
	slots_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	column.add_child(slots_label)

	_slots_row = HBoxContainer.new()
	_slots_row.add_theme_constant_override("separation", 8)
	column.add_child(ActionPanel.wrap_scrollable(_slots_row))

	return panel


## 右下「全部角色」區塊:獨立木框羊皮紙面板,撐滿剩餘高度,裡面是可篩選排序的
## CharacterSelectBar——角色數量一多,卡片網格會長得比面板還高,包一層捲動框讓超出的部分
## 自己捲動,不要讓外層 CharacterSelectOverlay 的內容整包一起被撐高(見
## stronghold_marriage_panel.gd 的 _build_proposer_panel() 同一套做法)。
func _build_picker_panel() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UiStyle.apply_parchment_panel(panel, 700.0, 380.0)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(column)

	var title := Label.new()
	title.text = "全部角色"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	column.add_child(title)

	_select_bar = CharacterSelectBar.new()
	column.add_child(ActionPanel.wrap_scrollable(_select_bar))

	return panel


func _rebuild_slots() -> void:
	for child in _slots_row.get_children():
		child.queue_free()

	var dispatched := BaseDispatchStore.get_dispatched_characters(_building.type)
	for i in range(BaseBuildingProgressStore.get_max_workers(_building.type)):
		var character: Character = dispatched[i] if i < dispatched.size() else null
		_slots_row.add_child(_build_slot(character))


func _build_slot(character: Character) -> Control:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = AVATAR_SLOT_SIZE
	slot.add_theme_stylebox_override("panel", UiStyle.parchment_row_style(UiStyle.PARCHMENT_ROW_BORDER, 1, 8, 0.0, 0.0, 0))

	if character == null:
		return slot

	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	slot.tooltip_text = character.full_name

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
			_rebuild_slots()
			_select_bar.refresh()
	)
	return slot


## 已在此工作/小隊隊長的卡片本身反灰擋掉點擊(見 _make_dispatch_card()),不會進到這裡;
## 派駐在別的建築的人卡片維持可點,但不直接搶過來,先跳確認(_confirm_reassign())。已編入
## 小隊的非隊長成員、以及其餘(目前沒有派駐任何建築也沒編隊)都是直接嘗試指派——
## BaseDispatchStore.dispatch() 內部會自動把前者移出小隊,呼叫端不用另外判斷;滿額時
## dispatch() 回傳 false、什麼都不變,不需要額外判斷或提示。滿額判斷要在跳確認之前先擋:
## 不然玩家看到「是否改安排到 YYY 工作?」按下確定卻發現滿額被 dispatch() 無聲擋掉,一頭霧水
## ——這裡直接整個不反應,連確認框都不跳。
func _on_list_card_selected(character: Character) -> void:
	if BaseDispatchStore.get_dispatched_character_ids(_building.type).size() >= BaseBuildingProgressStore.get_max_workers(_building.type):
		return

	_detail_view.set_character(character)

	var current_building_type := BaseDispatchStore.get_dispatched_building_type(character.id)
	if current_building_type != -1 and current_building_type != _building.type:
		_confirm_reassign(character, current_building_type)
		return

	BaseDispatchStore.dispatch(_building.type, character.id)
	_rebuild_slots()
	_select_bar.refresh()


## 「OOO 目前在XXX工作,是否改安排到YYY工作?」——確定才真的把人從舊建築召回、指派到這裡
## (dispatch() 內部本來就會先 undispatch_character() 清掉舊的派駐,見
## Scripts/Autoload/base_dispatch_store.gd,這裡不用自己先呼叫 undispatch())。
func _confirm_reassign(character: Character, current_building_type: int) -> void:
	var current_name := GameEnums.building_type_label(current_building_type)
	var message := "%s 目前在%s工作，是否改安排到%s工作？" % [character.full_name, current_name, _building.name]
	ConfirmDialog.ask(message, func() -> void:
		BaseDispatchStore.dispatch(_building.type, character.id)
		_rebuild_slots()
		_select_bar.refresh()
	, Callable(), "確定", "取消")


## 完整素質資訊在左側 CharacterDetailView,卡片只需要負責「已在此工作/小隊隊長/派駐別的
## 建築/已編入小隊(非隊長)」四種狀態——前兩者不可點(反灰),後兩者維持可點但視覺上一樣
## 反灰(force_dim)示意非「目前沒派駐任何建築也沒編隊」的直接可指派狀態:派駐別的建築走
## 確認流程(見 _on_list_card_selected()/_confirm_reassign()),已編入小隊的非隊長成員點下去
## 直接指派——BaseDispatchStore.dispatch() 內部會自動把它移出小隊,小隊至少要留一位隊長,
## 所以隊長本身不可點(見 CLAUDE.md 這次的雙向轉換規則)。tooltip 明確顯示原因,取代含糊的
## 「在其他地方工作」。
func _make_dispatch_card(character: Character) -> Control:
	var is_here := BaseDispatchStore.get_dispatched_character_ids(_building.type).has(character.id)
	var dispatched_building_type := BaseDispatchStore.get_dispatched_building_type(character.id)
	var is_elsewhere := not is_here and dispatched_building_type != -1
	var is_party_leader := PartyStore.party != null and PartyStore.party.leader == character
	var is_in_party := PartyStore.party != null and PartyStore.party.characteres.has(character)
	var assignable := not is_here and not is_party_leader
	var unavailable_reason := ""
	if is_here:
		unavailable_reason = "在此工作"
	elif is_party_leader:
		unavailable_reason = "小隊隊長，無法派遣"
	elif is_elsewhere:
		unavailable_reason = "在%s工作" % GameEnums.building_type_label(dispatched_building_type)
	elif is_in_party:
		unavailable_reason = "已編入小隊"
	return CharacterAvatarCard.new(character, assignable, unavailable_reason, is_elsewhere or is_in_party)
