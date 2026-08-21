extends Control

# =========================================================
# 告白/被告白畫面:左側固定寬度顯示目前聚焦角色的詳細資訊(CharacterDetailView,
# 跟 CharacterRoster/CharacterPanel 共用同一顆元件),右上角接受/第二顆按鈕(文字
# 依模式是「婉拒」或「取消」),右側 FaceOff 是我方/對方頭像對照,下方一律顯示
# 可篩選排序的我方角色選人清單(CharacterSortFilterBar + CharacterAvatarCard,比照
# character_roster.gd 的寫法)。
#
# 點對方頭像不會換左側資料(只有我方頭像/選人清單點了才換),左側預設顯示的是
# 「被告白的人」:INCOMING 是我方,OUTGOING 是對方。
#
# 下方選人清單點選一律會真的換我方人選(見 _on_picker_character_selected),兩種模式
# 都一樣——INCOMING 模式下預設 _self_character 是對方原本屬意的 courted,但玩家可以
# 改選清單裡其他符合資格的角色頂替上場;選了不是 courted 的人,接受機率就會降低
# (見 MarriageRule.acceptance_chance(),由呼叫端 town_tavern_event.gd 骰定並決定
# 後續分支對話),這裡不算機率、不寫任何角色資料。
#
# 進場資料一律透過 SceneHandoffStore 這個通用 mailbox autoload 交接(key 是
# MarriageProposalRequest.MAILBOX_KEY,見 System/marriage/marriage_proposal_request.gd)。
# 這裡完全不寫 Character.mate/parent/children——接受/婉拒/取消只是把結果丟回呼叫端
# 傳入的 callback,實際資料寫入時機由呼叫端決定(見
# System/event/town/town_tavern_event.gd)。
# =========================================================

@onready var title_label: Label = $Title
@onready var detail_panel: PanelContainer = $MainRow/DetailPanel
@onready var detail_margin: MarginContainer = $MainRow/DetailPanel/DetailMargin
@onready var face_off_panel: PanelContainer = $MainRow/RightPanel/FaceOffPanel
@onready var picker_panel: PanelContainer = $MainRow/RightPanel/PickerPanel
@onready var picker_scroll_container: ScrollContainer = $MainRow/RightPanel/PickerPanel/PickerMargin/PickerVBox/ScrollContainer
@onready var self_row: HBoxContainer = $MainRow/RightPanel/FaceOffPanel/FaceOffMargin/FaceOffRow/SelfSlot/SelfRow
@onready var self_info_label: Label = $MainRow/RightPanel/FaceOffPanel/FaceOffMargin/FaceOffRow/SelfSlot/SelfRow/SelfInfo
@onready var target_row: HBoxContainer = $MainRow/RightPanel/FaceOffPanel/FaceOffMargin/FaceOffRow/TargetSlot/TargetRow
@onready var target_info_label: Label = $MainRow/RightPanel/FaceOffPanel/FaceOffMargin/FaceOffRow/TargetSlot/TargetRow/TargetInfo
@onready var accept_button: Button = $ActionRow/AcceptButton
@onready var second_button: Button = $ActionRow/SecondButton
@onready var sort_filter_bar: CharacterSortFilterBar = $MainRow/RightPanel/PickerPanel/PickerMargin/PickerVBox/SortFilterBar
@onready var picker_grid: HFlowContainer = $MainRow/RightPanel/PickerPanel/PickerMargin/PickerVBox/ScrollContainer/PickerGrid

var _detail_view: CharacterDetailView
var _self_character: Character
var _target_character: Character
## 事件一開始就指定好的告白對象(見 MarriageProposalRequest.self_character),不隨
## 玩家之後在下方清單點別人預覽而改變——用來在清單裡永久標記「這是原本要告白的人」,
## 跟 _self_character(目前實際會拿去 _resolve() 的人選)是兩個獨立概念。
var _courted_character: Character
var _mode: GameEnums.ProposalMode
var _result_callback: Callable
var _self_card: CharacterAvatarCard


func _ready() -> void:
	for button in [accept_button, second_button]:
		UiStyle.apply_wood_plaque_button(button, 16.0, 8.0)
		button.add_theme_font_size_override("font_size", 18)
	UiStyle.apply_parchment_panel(face_off_panel, 1120.0, 220.0)
	UiStyle.apply_parchment_panel(picker_panel, 1120.0, 556.0)
	UiStyle.apply_parchment_scrollbar(picker_scroll_container)
	# DetailPanel 自己的 DetailMargin 已經有 20/14/20/14 留白,這裡用比大面板預設值
	# (30/50/30/50)小一點的 content_margin,理由跟 character_panel.gd 的 PanelBox 一樣。
	UiStyle.apply_parchment_panel(detail_panel, 400.0, 792.0, 16.0, 18.0, 16.0, 18.0)

	# take() 讀完立刻清空,跟原本 ProposalStore 在這裡手動清 pending 欄位的行為一致。
	var handoff := SceneHandoffStore.take(MarriageProposalRequest.MAILBOX_KEY)
	var request := handoff.payload as MarriageProposalRequest if handoff != null else null
	_target_character = request.target_character if request != null else null
	_self_character = request.self_character if request != null else null
	_courted_character = _self_character
	_mode = request.mode if request != null else GameEnums.ProposalMode.OUTGOING
	_result_callback = handoff.result_callback if handoff != null else Callable()

	if _target_character == null:
		# 防呆:不是從 SceneHandoffStore.queue() 的正常流程進來(例如直接開這個場景測試)。
		title_label.text = "（無告白資料）"
		return

	_detail_view = CharacterDetailView.new()
	_detail_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_margin.add_child(_detail_view)

	# 對方頭像不接 character_selected——點對方不會換左側資料(見下方 _on_avatar_focused
	# 只給我方頭像/選人清單用)。
	var target_card := CharacterAvatarCard.new(_target_character)
	target_row.add_child(target_card)
	target_info_label.text = _character_info_text(_target_character)

	_set_self_card(_self_character)

	accept_button.pressed.connect(_on_accept_pressed)
	second_button.pressed.connect(_on_second_pressed)
	sort_filter_bar.changed.connect(_refresh_picker)

	match _mode:
		GameEnums.ProposalMode.INCOMING:
			title_label.text = "有人向你告白"
			second_button.text = "婉拒"
			accept_button.disabled = false
		GameEnums.ProposalMode.OUTGOING:
			title_label.text = "選擇告白對象"
			second_button.text = "取消"
			accept_button.disabled = _self_character == null

	_refresh_picker()
	# 左側預設顯示「被告白的人」:INCOMING 是我方(對方主動找上門的那位),
	# OUTGOING 是對方(我方角色還沒選,先讓玩家看清楚要告白的對象是誰)。
	_focus_character(_self_character if _mode == GameEnums.ProposalMode.INCOMING else _target_character)


## 我方頭像卡:CharacterAvatarCard 的頭像/tooltip 只在 _ready() 決定一次,換角色
## 要整張換掉,不能直接改 .character 屬性。
func _set_self_card(character: Character) -> void:
	if _self_card != null:
		_self_card.queue_free()
	_self_card = CharacterAvatarCard.new(character)
	_self_card.character_selected.connect(_on_avatar_focused)
	self_row.add_child(_self_card)
	self_info_label.text = _character_info_text(character)


## 姓名/年齡/性別各佔一行,顯示在 FaceOff 頭像右側,己方對方共用同一份格式。
func _character_info_text(character: Character) -> String:
	if character == null:
		return ""
	return "%s\n%d 歲\n%s" % [character.full_name, character.age, GameEnums.gender_symbol(character.gender)]


func _refresh_picker() -> void:
	for child in picker_grid.get_children():
		child.queue_free()

	var eligible: Array[Character] = []
	for character in CharacterRosterStore.all_characteres:
		if MarriageRule.can_propose(character, _target_character):
			eligible.append(character)
	eligible = sort_filter_bar.filter.apply(eligible)

	for character in eligible:
		var card := CharacterAvatarCard.new(character)
		card.selected = character == _self_character
		card.character_selected.connect(_on_picker_character_selected)
		if character == _courted_character:
			_add_courted_marker(card)
		picker_grid.add_child(card)


## 在清單卡片右上角疊一個小標記,標出「事件一開始就指定的告白對象」——跟卡片本身
## 的 selected 金色邊框(目前點誰預覽)是兩件事,不會互相蓋掉。
func _add_courted_marker(card: CharacterAvatarCard) -> void:
	var marker := Label.new()
	marker.text = "被告白"
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	marker.position = Vector2(-20, -6)
	marker.add_theme_font_size_override("font_size", 20)
	card.add_child(marker)


func _on_picker_character_selected(character: Character) -> void:
	for child in picker_grid.get_children():
		if child is CharacterAvatarCard:
			child.selected = child.character == character
	_focus_character(character)

	# 兩種模式點清單都真的換我方人選——INCOMING 模式下換成不是 courted 的人會降低
	# 接受機率(見 MarriageRule.acceptance_chance()),但這裡不算機率,只負責回報
	# 玩家最終選了誰。
	_self_character = character
	_set_self_card(character)
	accept_button.disabled = false


func _on_avatar_focused(character: Character) -> void:
	if character != null:
		_focus_character(character)


func _focus_character(character: Character) -> void:
	_detail_view.set_character(character)


func _on_accept_pressed() -> void:
	_resolve(true)


func _on_second_pressed() -> void:
	_resolve(false)


func _resolve(accepted: bool) -> void:
	if _result_callback.is_valid():
		_result_callback.call(accepted, _self_character, _target_character)
	else:
		NavigationStore.go_back()
