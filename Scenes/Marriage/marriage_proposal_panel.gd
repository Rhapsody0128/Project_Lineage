class_name MarriageProposalPanel
extends VBoxContainer

# =========================================================
# 告白畫面內容:塞進共用的 Scenes/ActionPanel/action_panel.gd(autoload)顯示(見
# System/event/town/town_tavern_event.gd 的 _open_marriage_panel() 呼叫
# ActionPanel.open_custom()),不是獨立場景,疊加在觸發事件當下的對話畫面上。左側固定寬度
# 顯示目前聚焦角色的詳細資訊(CharacterDetailView,跟 CharacterRoster/CharacterPanel 共用
# 同一顆元件),右側 FaceOff 是我方/對方頭像對照,下方是可篩選排序的我方角色選人清單
# (CharacterSelectBar + CharacterAvatarCard,見 Scenes/CharacterSelect/)。標題文字交給
# 呼叫端傳給 ActionPanel.open_custom() 的 title 顯示,這裡不重複畫一次(比照
# base_action_panel.gd 的 BaseBuildingPanelContent 既有做法)。
#
# 只有「接受」一顆按鈕,塞進 ActionPanel 標題列跟 × 同一行(ActionPanel.
# set_title_action_button(),見 _ready()),不再另外佔一整排——沒有獨立的「婉拒/取消」鈕,
# × 本身就會呼叫 decline()(見下方),效果跟按婉拒/取消完全一樣,重複放一顆沒有意義。
# 接受/婉拒/取消一律呼叫 ActionPanel.close(false)(trigger_callback=false,避免額外觸發
# open_custom() 傳入的 on_close——那個 callback 是給 × 鈕走的預設路徑,這裡已經自己決定
# 好接下來要做什麼,不需要再讓 on_close 跑一次),再把結果丟回呼叫端傳入的 on_result
# callback,這裡自己不知道也不需要知道自己被誰疊在最上層。
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
# 進場資料改由呼叫端在 instantiate() 之後直接呼叫 setup() 傳入——不再靠 SceneHandoffStore
# 轉手(舊版 MarriageProposalRequest/MAILBOX_KEY 已刪除):這裡不切場景,呼叫端的事件物件
# (TownTavernEvent)全程都還活著,直接用 closure 就能撐住 callback,不需要那一層 mailbox。
# 接受/婉拒/取消只是把結果丟回呼叫端傳入的 on_result callback,實際資料寫入時機由呼叫端
# 決定,這裡完全不寫 Character.mate。
# =========================================================

@onready var detail_panel: PanelContainer = $MainRow/DetailPanel
@onready var face_off_panel: PanelContainer = $MainRow/RightPanel/FaceOffPanel
@onready var picker_panel: PanelContainer = $MainRow/RightPanel/PickerPanel
@onready var self_row: HBoxContainer = $MainRow/RightPanel/FaceOffPanel/FaceOffRow/SelfSlot/SelfRow
@onready var self_info_label: Label = $MainRow/RightPanel/FaceOffPanel/FaceOffRow/SelfSlot/SelfRow/SelfInfo
@onready var target_row: HBoxContainer = $MainRow/RightPanel/FaceOffPanel/FaceOffRow/TargetSlot/TargetRow
@onready var target_info_label: Label = $MainRow/RightPanel/FaceOffPanel/FaceOffRow/TargetSlot/TargetRow/TargetInfo
@onready var picker_vbox: VBoxContainer = $MainRow/RightPanel/PickerPanel/PickerVBox

var accept_button: Button

var _detail_view: CharacterDetailView
var _select_bar: CharacterSelectBar
var _self_character: Character
var _target_character: Character
## 事件一開始就指定好的告白對象(見 setup() 的 self_character 參數),不隨玩家之後在下方
## 清單點別人預覽而改變——用來在清單裡永久標記「這是原本要告白的人」,跟 _self_character
## (目前實際會拿去 _resolve() 的人選)是兩個獨立概念。
var _courted_character: Character
var _mode: GameEnums.ProposalMode
var _on_result: Callable
var _self_card: CharacterAvatarCard


func _ready() -> void:
	UiStyle.apply_parchment_panel(face_off_panel, 760.0, 220.0)
	UiStyle.apply_parchment_panel(picker_panel, 760.0, 480.0)

	_detail_view = CharacterDetailView.new()
	_detail_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.add_child(_detail_view)

	# detail_panel 的寬度來自剛掛進去的 _detail_view 自己宣告的 custom_minimum_size.x
	# (CharacterDetailView.PANEL_WIDTH)——用 get_combined_minimum_size() 現場問出來當
	# 第一次套用的猜測值,一定要等 _detail_view 已經掛進樹裡再呼叫,不然問到的還是 0。
	# 高度撐滿 MainRow,先用目前的自然內容高度墊著,交給 apply_parchment_panel() 內建的
	# resized 訊號自動補正。
	var panel_size := detail_panel.get_combined_minimum_size()
	UiStyle.apply_parchment_panel(detail_panel, panel_size.x, panel_size.y)

	# 「接受」跟 ActionPanel 標題列的 × 放同一行,不再另外占一整排——沒有獨立的婉拒/取消鈕,
	# × 本身就會呼叫 decline(),效果完全一樣。
	accept_button = Button.new()
	accept_button.text = "接受"
	UiStyle.apply_wood_plaque_button(accept_button, 16.0, 6.0)
	accept_button.add_theme_font_size_override("font_size", 16)
	accept_button.pressed.connect(_on_accept_pressed)
	ActionPanel.set_title_action_button(accept_button)


## 呼叫端(town_tavern_event.gd)在 instantiate() 之後立刻呼叫一次,取代原本靠
## SceneHandoffStore 轉手 MarriageProposalRequest 的做法。on_result 簽名
## func(accepted: bool, self_character: Character, target_character: Character) -> void。
func setup(target_character: Character, self_character: Character, mode: GameEnums.ProposalMode, on_result: Callable) -> void:
	_target_character = target_character
	_self_character = self_character
	_courted_character = self_character
	_mode = mode
	_on_result = on_result

	var target_card := CharacterAvatarCard.new(_target_character)
	target_row.add_child(target_card)
	target_info_label.text = _character_info_text(_target_character)

	_set_self_card(_self_character)

	_select_bar = CharacterSelectBar.new()
	# 角色數量一多,卡片網格會長得比 PickerPanel 還高——包一層捲動框讓超出的部分自己
	# 捲動,不要讓外層 ActionPanel 的 ItemsList 整包一起被撐高、變成捲動整個告白面板
	# (見 action_panel.gd 的 wrap_scrollable())。
	picker_vbox.add_child(ActionPanel.wrap_scrollable(_select_bar))
	_select_bar.character_selected.connect(_on_picker_character_selected)

	var eligible: Array[Character] = []
	for character in CharacterRosterStore.all_characteres:
		if MarriageRule.can_propose(character, _target_character):
			eligible.append(character)
	_select_bar.setup(eligible, _build_picker_card, -1, true)
	_select_bar.set_selected(_self_character)

	match _mode:
		GameEnums.ProposalMode.INCOMING:
			accept_button.disabled = false
		GameEnums.ProposalMode.OUTGOING:
			accept_button.disabled = _self_character == null

	# 左側預設顯示「被告白的人」:INCOMING 是我方(對方主動找上門的那位),OUTGOING 是
	# 對方(我方角色還沒選,先讓玩家看清楚要告白的對象是誰)。
	_focus_character(_self_character if _mode == GameEnums.ProposalMode.INCOMING else _target_character)


## 清單卡片一律用 CharacterAvatarCard,「被告白」的人額外疊一個小標記(跟卡片本身的
## selected 金色邊框是兩件事,不會互相蓋掉)。
func _build_picker_card(character: Character) -> Control:
	var card := CharacterAvatarCard.new(character)
	if character == _courted_character:
		var marker := Label.new()
		marker.text = "被告白"
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marker.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		marker.position = Vector2(-20, -6)
		marker.add_theme_font_size_override("font_size", 20)
		card.add_child(marker)
	return card


## 我方頭像卡:CharacterAvatarCard 的頭像/tooltip 只在 _ready() 決定一次,換角色要整張
## 換掉,不能直接改 .character 屬性。
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


func _on_picker_character_selected(character: Character) -> void:
	_focus_character(character)
	# 兩種模式點清單都真的換我方人選——INCOMING 模式下換成不是 courted 的人會降低接受
	# 機率(見 MarriageRule.acceptance_chance()),但這裡不算機率,只負責回報玩家最終選了誰。
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


## × 按鈕(ActionPanel 標題列的關閉鍵,見 _open_marriage_panel() 傳給
## ActionPanel.open_custom() 的 on_close)呼叫,視同「婉拒/取消」——玩家必須有個
## 出口,不能沒有反應。
func decline() -> void:
	_resolve(false)


func _resolve(accepted: bool) -> void:
	ActionPanel.close(false)
	_on_result.call(accepted, _self_character, _target_character)
