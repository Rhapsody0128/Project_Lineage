class_name StrongholdMarriagePanel
extends VBoxContainer

# =========================================================
# 城鎮中心聯姻面板——第一階段只負責選「聯姻角色」與「寄信國家」,不含候選人選擇(候選人是
# 盲選,發生在確認之後的 Dialogue 事件裡,見 System/event/base/base_marriage_event.gd)。
# 塞進 Scripts/UI/fullscreen_overlay.gd 的 FullscreenOverlay 顯示(見 Scenes/Base/
# base_action_panel.gd 的 _open_stronghold_marriage_panel()),不切場景、不借用
# ActionPanel,近全螢幕疊在目前顯示中的城鎮中心建築面板最上層。版面結構:左側
# CharacterDetailView 顯示目前聚焦角色的完整資料,右側是兩個各自獨立、同時顯示的區塊——
# 上方「寄信國家」(六國按鈕 + 好感度)、下方「聯姻角色」(已篩過未婚角色的清單),不用
# TabContainer 切換,兩塊同時可見可選,順序不拘。main_row/detail_panel 都用
# size_flags_vertical = EXPAND_FILL 撐滿 FullscreenOverlay.content_slot 給的整個高度,不用
# 像塞進 ActionPanel 的 ScrollContainer 時那樣另外給高度下限。
#
# 聯姻角色預設聚焦清單第一位(呼叫端 setup() 傳入的 characters 已經是 MarriageRule.
# eligible_proposers() 篩過的結果)。
#
# overlay 欄位由呼叫端在 instantiate() 之後、setup() 之前直接賦值。取消/× 都走 overlay
# 自己 close() 掉自己(建築面板本來就沒被替換,不用重開);確認聯姻由這裡自己
# overlay.close() 讓路,再呼叫 setup() 傳入的 on_confirmed(proposer, nation) 交棒給
# BaseMarriageEvent.trigger()。
# =========================================================

## 呼叫端在 instantiate() 之後、setup() 之前賦值——見檔案開頭註解。
var overlay: FullscreenOverlay

var _detail_view: CharacterDetailView
var _proposer_bar: CharacterSelectBar
var _confirm_button: Button
var _nation_button_group: ButtonGroup

var _proposal_character: Character
var _proposal_nation: int = -1
var _on_confirmed: Callable


func _ready() -> void:
	add_theme_constant_override("separation", 16)

	var main_row := HBoxContainer.new()
	main_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_row.add_theme_constant_override("separation", 16)
	add_child(main_row)

	var detail_panel := PanelContainer.new()
	detail_panel.custom_minimum_size = Vector2(400, 0)
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UiStyle.apply_parchment_panel(detail_panel, 400.0, 700.0, 16.0, 18.0, 16.0, 18.0)
	main_row.add_child(detail_panel)

	_detail_view = CharacterDetailView.new()
	_detail_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.add_child(_detail_view)

	var right_column := VBoxContainer.new()
	right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_column.add_theme_constant_override("separation", 16)
	main_row.add_child(right_column)

	right_column.add_child(_build_nation_panel())
	right_column.add_child(_build_proposer_panel())

	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_END
	action_row.add_theme_constant_override("separation", 16)
	add_child(action_row)

	var cancel_button := Button.new()
	cancel_button.text = "取消"
	UiStyle.apply_wood_plaque_button(cancel_button, 16.0, 8.0)
	cancel_button.add_theme_font_size_override("font_size", 18)
	cancel_button.pressed.connect(func() -> void: overlay.close())
	action_row.add_child(cancel_button)

	_confirm_button = Button.new()
	_confirm_button.text = "確認聯姻"
	UiStyle.apply_wood_plaque_button(_confirm_button, 16.0, 8.0)
	_confirm_button.add_theme_font_size_override("font_size", 18)
	_confirm_button.disabled = true
	_confirm_button.pressed.connect(_on_confirm_pressed)
	action_row.add_child(_confirm_button)


## 上方「寄信國家」區塊:獨立木框羊皮紙面板,固定高度,六國按鈕排成一列 grid,附好感度
## 等級——不含候選人清單,候選人改在確認之後的盲選 Dialogue 事件裡才生成(見
## base_marriage_event.gd),這裡選國家只是決定要寄信去哪一國。
func _build_nation_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 210)
	UiStyle.apply_parchment_panel(panel, 700.0, 210.0, 16.0, 14.0, 16.0, 14.0)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	var title := Label.new()
	title.text = "寄信國家"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	column.add_child(title)

	var hint := Label.new()
	hint.text = "好感度愈高,回信人選評級愈好。"
	hint.add_theme_color_override("font_color", UiStyle.PARCHMENT_SUBTITLE_COLOR)
	column.add_child(hint)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	column.add_child(grid)

	_nation_button_group = ButtonGroup.new()
	for nation in GameEnums.BloodlineNation.values():
		grid.add_child(_build_nation_button(nation))

	return panel


func _build_nation_button(nation: int) -> Button:
	var button := Button.new()
	var favor := NationFavorStore.get_favor(nation)
	button.text = "%s國（好感度 %s）" % [GameEnums.bloodline_nation_label(nation), NationFavorRank.label_for_favor(favor)]
	button.toggle_mode = true
	button.button_group = _nation_button_group
	UiStyle.apply_wood_plaque_button(button, 12.0, 6.0)
	button.add_theme_font_size_override("font_size", 15)
	button.pressed.connect(func() -> void: _on_nation_selected(nation))
	return button


## 下方「聯姻角色」區塊:獨立木框羊皮紙面板,撐滿剩餘高度,裡面是已篩過未婚角色的
## CharacterSelectBar。
func _build_proposer_panel() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UiStyle.apply_parchment_panel(panel, 700.0, 380.0, 16.0, 14.0, 16.0, 14.0)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(column)

	var title := Label.new()
	title.text = "聯姻角色"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	column.add_child(title)

	_proposer_bar = CharacterSelectBar.new()
	_proposer_bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_proposer_bar.character_selected.connect(_on_proposer_selected)
	column.add_child(_proposer_bar)

	return panel


## 聯姻流程唯一的入口:eligible 是已經篩過(未婚且未禁用,見 MarriageRule.eligible_proposers())
## 的角色清單,呼叫端(base_action_panel.gd)按下「聯姻」鈕時保證非空才會開這個面板。
## on_confirmed 簽名 func(proposer: Character, nation: int) -> void,按下「確認聯姻」時
## 觸發,面板自己先 overlay.close() 讓路,不需要呼叫端重複處理。
func setup(eligible: Array[Character], on_confirmed: Callable) -> void:
	_on_confirmed = on_confirmed
	_proposal_character = eligible[0]

	_proposer_bar.setup(eligible, _build_proposer_card, -1, true)
	_proposer_bar.set_selected(_proposal_character)
	_focus_character(_proposal_character)


func _build_proposer_card(character: Character) -> Control:
	return CharacterAvatarCard.new(character)


func _on_proposer_selected(character: Character) -> void:
	_proposal_character = character
	_focus_character(character)


func _on_nation_selected(nation: int) -> void:
	_proposal_nation = nation
	_update_confirm_button()


func _focus_character(character: Character) -> void:
	_detail_view.set_character(character)


func _update_confirm_button() -> void:
	_confirm_button.disabled = _proposal_nation == -1


func _on_confirm_pressed() -> void:
	overlay.close()
	_on_confirmed.call(_proposal_character, _proposal_nation)
