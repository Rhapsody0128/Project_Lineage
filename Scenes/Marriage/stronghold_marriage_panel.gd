class_name StrongholdMarriagePanel
extends VBoxContainer

# =========================================================
# 城鎮中心聯姻面板——第一階段只負責選「聯姻角色」與「寄信國家」,不含候選人選擇(候選人是
# 盲選,發生在確認之後的 Dialogue 事件裡,見 System/event/base/base_marriage_event.gd)。
# 塞進共用的 Scenes/ActionPanel/action_panel.gd(autoload)顯示(見 Scenes/Base/
# base_action_panel.gd 的 _open_stronghold_marriage_panel()),不切場景——直接換掉
# ActionPanel 目前顯示的城鎮中心建築面板內容(不是疊在上面另開一層)。版面結構:左側
# CharacterDetailView 顯示目前聚焦角色的完整資料,右側是兩個各自獨立、同時顯示的區塊——
# 上方「寄信國家」(六國按鈕 + 好感度)、下方「聯姻角色」(已篩過未婚角色的清單),不用
# TabContainer 切換,兩塊同時可見可選,順序不拘。
#
# 聯姻角色預設聚焦清單第一位(呼叫端 setup() 傳入的 characters 已經是 MarriageRule.
# eligible_proposers() 篩過的結果)。
#
# 沒有獨立的取消鈕——× 本來就走 ActionPanel.close()(trigger_callback 預設 true),觸發
# 呼叫端傳給 open_custom() 的 on_close,重新呼叫 BaseBuildingEvent.open_action_panel() 開
# 一份全新的城鎮中心建築面板(這份面板本身已經在換掉 ActionPanel 內容的當下被釋放,回不去
# 了,見 _open_stronghold_marriage_panel() 註解),再放一顆「取消」鈕只是重複同一個動作。
# 「確認聯姻」改塞進 ActionPanel 標題列(ActionPanel.set_title_action_button(),見
# _ready()),跟 × 同一行,不再另外佔一整排——比照 BaseBuildingPanelContent 的
# 建造/升級鈕擺法(見 base_action_panel.gd 開頭註解)。確認聯姻只需要呼叫 setup() 傳入的
# on_confirmed(proposer, nation)——ActionPanel.close(false) 交給呼叫端的 on_confirmed
# callback 自己處理(要接著切場景去 BaseMarriageEvent,trigger_callback 必須是 false,
# 不能讓 on_close 又跑一次重開面板)。
# =========================================================

var _detail_view: CharacterDetailView
var _proposer_bar: CharacterSelectBar
var _confirm_button: Button
var _nation_button_group: ButtonGroup

var _proposal_character: Character
var _proposal_nation: int = -1
var _on_confirmed: Callable


func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 16)

	var main_row := HBoxContainer.new()
	main_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_row.add_theme_constant_override("separation", 16)
	add_child(main_row)

	var detail_panel := PanelContainer.new()
	main_row.add_child(detail_panel)

	_detail_view = CharacterDetailView.new()
	_detail_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.add_child(_detail_view)

	# detail_panel 的寬度來自剛掛進去的 _detail_view 自己宣告的 custom_minimum_size.x
	# (CharacterDetailView.PANEL_WIDTH)——用 get_combined_minimum_size() 現場問出來當
	# 第一次套用的猜測值,一定要等 _detail_view 已經掛進樹裡再呼叫,不然問到的還是 0。
	# 高度撐滿 main_row,先用目前的自然內容高度墊著,交給 apply_parchment_panel() 內建的
	# resized 訊號自動補正。
	var panel_size := detail_panel.get_combined_minimum_size()
	UiStyle.apply_parchment_panel(detail_panel, panel_size.x, panel_size.y)

	var right_column := VBoxContainer.new()
	right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_column.add_theme_constant_override("separation", 16)
	main_row.add_child(right_column)

	right_column.add_child(_build_nation_panel())
	right_column.add_child(_build_proposer_panel())

	# 「確認聯姻」跟 ActionPanel 標題列的 × 放同一行,不再另外占一整排——沒有取消鈕,
	# × 本來就是同樣的「放棄、回到建築面板」效果。
	_confirm_button = Button.new()
	_confirm_button.text = "確認聯姻"
	UiStyle.apply_wood_plaque_button(_confirm_button, 16.0, 6.0)
	_confirm_button.add_theme_font_size_override("font_size", 16)
	_confirm_button.disabled = true
	_confirm_button.pressed.connect(_on_confirm_pressed)
	ActionPanel.set_title_action_button(_confirm_button)


## 上方「寄信國家」區塊:獨立木框羊皮紙面板,固定高度,六國按鈕排成一列 grid,附好感度
## 等級——不含候選人清單,候選人改在確認之後的盲選 Dialogue 事件裡才生成(見
## base_marriage_event.gd),這裡選國家只是決定要寄信去哪一國。
func _build_nation_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 210)
	UiStyle.apply_parchment_panel(panel, 700.0, 210.0)

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

	# 六國固定放得下 210 高度,但包一層捲動框防呆——之後國家數量變多也只會在這個框內部
	# 自己捲動,不會把整包 StrongholdMarriagePanel 撐高、拖累外層 ActionPanel 一起捲(見
	# action_panel.gd 的 wrap_scrollable())。
	column.add_child(ActionPanel.wrap_scrollable(grid))

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
	UiStyle.apply_parchment_panel(panel, 700.0, 380.0)

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
	_proposer_bar.character_selected.connect(_on_proposer_selected)

	# 角色數量一多,CharacterSelectBar 的卡片網格會長得比這個框(380 高)還高——包一層
	# 捲動框讓超出的部分自己捲動,不要讓外層 ActionPanel 的 ItemsList 整包一起被撐高、
	# 變成捲動整個聯姻面板(見 action_panel.gd 的 wrap_scrollable())。
	column.add_child(ActionPanel.wrap_scrollable(_proposer_bar))

	return panel


## 聯姻流程唯一的入口:eligible 是已經篩過(未婚且未禁用,見 MarriageRule.eligible_proposers())
## 的角色清單,呼叫端(base_action_panel.gd)按下「聯姻」鈕時保證非空才會開這個面板。
## on_confirmed 簽名 func(proposer: Character, nation: int) -> void,按下「確認聯姻」時觸發,
## 關閉 ActionPanel(trigger_callback=false,避免又觸發重開建築面板)是呼叫端 on_confirmed
## callback 自己的責任,見 _open_stronghold_marriage_panel() 註解。
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
	_on_confirmed.call(_proposal_character, _proposal_nation)
