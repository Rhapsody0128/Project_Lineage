extends Control

# =========================================================
# 角色列表畫面:左側欄(DetailColumn)顯示目前選取角色的詳細資訊
# (CharacterDetailView,直式排版,跟彈出式 CharacterPanel 共用同一顆元件)——欄寬固定
# 是 CharacterDetailView 自己攜帶的 PANEL_WIDTH,不是這個場景設的,右側 RosterPanel
# (size_flags_horizontal=EXPAND_FILL)自動撐滿剩餘寬度,是
# CharacterRosterStore.all_characteres(玩家擁有的全部角色,不是 PartyStore 的
# 隊伍編成)的頭像卡片網格,排序/篩選比照 PartyEdit 候補清單共用
# CharacterSortFilterBar + System 層的 CharacterSortFilter。點卡片切換左側顯示。
#
# 左側欄(DetailColumn)最上方多一列「解雇」/「觀看祖譜」按鈕(ActionButtonRow),
# 疊在 DetailPanel 面板「外面」(同一欄的上一列,不是塞進面板內的 DetailVBox)——
# 「觀看祖譜」原本是 CharacterDetailView 家族分頁裡的按鈕,這個場景改成把它跟「解雇」
# 並排移到最上方,不用先切到家族分頁才看得到,所以嵌入的 _detail_view 要關掉
# =========================================================

@onready var detail_panel: PanelContainer = $MainRow/DetailColumn/DetailPanel
@onready var detail_vbox: VBoxContainer = $MainRow/DetailColumn/DetailPanel/DetailVBox
@onready var dismiss_button: Button = $MainRow/DetailColumn/ActionButtonRow/DismissButton
@onready var view_family_tree_button: Button = $MainRow/DetailColumn/ActionButtonRow/ViewFamilyTreeButton
@onready var roster_panel: PanelContainer = $MainRow/RosterPanel
@onready var roster_title: Label = $MainRow/RosterPanel/RosterVBox/RosterTitle
@onready var roster_scroll_container: ScrollContainer = $MainRow/RosterPanel/RosterVBox/ScrollContainer
@onready var sort_filter_bar: CharacterSortFilterBar = $MainRow/RosterPanel/RosterVBox/SortFilterBar
@onready var roster_grid: HFlowContainer = $MainRow/RosterPanel/RosterVBox/ScrollContainer/RosterGrid
@onready var back_button: Button = $TopBar/BackButton

var _detail_view: CharacterDetailView
var _selected_card: CharacterAvatarCard


func _ready() -> void:
	UiStyle.apply_wood_plaque_button(back_button, 16.0, 8.0)
	back_button.add_theme_font_size_override("font_size", 18)
	for button in [dismiss_button, view_family_tree_button]:
		UiStyle.apply_wood_plaque_button(button, 16.0, 8.0)
		button.add_theme_font_size_override("font_size", 16)
	UiStyle.apply_parchment_panel(roster_panel, 1120.0, 792.0)
	UiStyle.apply_parchment_scrollbar(roster_scroll_container)

	_detail_view = CharacterDetailView.new()
	_detail_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_vbox.add_child(_detail_view)

	# DetailPanel 的寬度來自剛掛進去的 _detail_view 自己宣告的 custom_minimum_size.x
	# (CharacterDetailView.PANEL_WIDTH),高度是它目前的自然內容高度,還沒被 MainRow
	# 的 EXPAND_FILL 撐到跟 RosterPanel 同高——用 get_combined_minimum_size() 現場問出來
	# 當第一次套用的猜測值,一定要等 _detail_view 已經掛進樹裡再呼叫,不然問到的還是 0。
	# 之後撐高的部分交給 apply_parchment_panel() 內建的 resized 訊號自動補正。
	var panel_size := detail_panel.get_combined_minimum_size()
	UiStyle.apply_parchment_panel(detail_panel, panel_size.x, panel_size.y)

	sort_filter_bar.changed.connect(_refresh_grid)
	_refresh_grid()


func _on_back_pressed() -> void:
	NavigationStore.go_back()


## 解雇:把目前選取角色從兩份角色池移除——CharacterRosterStore(玩家可操控池)跟
## AllCharacterStore(角色總容量池,見 AllCharacterStore.is_full())都要移除,騰出的
## 容量才能真的讓玩家之後招募/生育補進新角色,不是只從清單畫面隱藏。彈確認框避免
## 手滑誤刪,跟 TownTavernEvent 角色列已滿時彈的「是否解雇」提示共用同一顆
## ConfirmDialog(見該檔案 _on_recruit_hero_selected())。
func _on_dismiss_pressed() -> void:
	if _selected_card == null:
		return
	var character := _selected_card.character
	if _is_protected_from_dismissal(character):
		MessageBar.show_message("%s 是主角、整團領導人或隊長,無法解雇" % character.full_name)
		return
	ConfirmDialog.ask("確定要解雇 %s 嗎？" % character.full_name, func(): _dismiss_character(character))


## 三種角色不能解雇:玩家固定主角(Character.is_protagonist)、目前整團領導人
## (LeaderStore.leader,見該檔案開頭註解——跟隊長是不同職責,解雇掉會讓玩家在城鎮中心/
## 大地圖對話突然沒人開得了口)、以及目前小隊隊長(PartyStore.party.leader)——隊長解雇
## 掉會讓小隊瞬間無人領軍,索性連選都不給選,不用等玩家解雇完才另外處理「隊伍沒隊長」的
## 補救邏輯。
func _is_protected_from_dismissal(character: Character) -> bool:
	if character.is_protagonist:
		return true
	if LeaderStore.leader == character:
		return true
	return PartyStore.party != null and PartyStore.party.leader == character


## 解雇後角色狀態顯示「已離隊」(見 CharacterStatusRule),所以要比照
## CharacterDeathController.kill() 一併清掉根據地派遣/小隊編成,不然會出現「已離隊」卻
## 還留在根據地工作或小隊裡的矛盾狀態。不比照死亡觸發 GAME OVER——主角/隊長本來就不能
## 解雇(見 _is_protected_from_dismissal()),不會發生小隊團滅的情況。
func _dismiss_character(character: Character) -> void:
	var dismissed_index := sort_filter_bar.filter.apply(CharacterRosterStore.all_characteres).find(character)

	character.is_dismissed = true
	BaseDispatchStore.undispatch_character(character.id)
	if PartyStore.grid != null:
		PartyStore.grid.remove(character)
	if PartyStore.party != null and PartyStore.party.characteres.has(character):
		PartyStore.party.characteres.erase(character)
		PartyStore.party.battle_cost_positions.erase(character)
		if PartyStore.party.leader == character:
			var remaining := PartyStore.party.characteres
			PartyStore.party.leader = remaining[0] if not remaining.is_empty() else null

	CharacterRosterStore.all_characteres.erase(character)
	AllCharacterStore.all_characteres.erase(character)
	_refresh_grid(dismissed_index)


## 觀看祖譜:比照 CharacterDetailView._on_view_family_tree_pressed() 的寫法,以目前
## 選取角色為起點交給 FamilyTree 場景(見該檔案 FOCUS_MAILBOX_KEY)。這個按鈕移到
## 不用再靠 CharacterDetailView 家族分頁裡那顆。
func _on_view_family_tree_pressed() -> void:
	if _selected_card == null:
		return
	SceneHandoffStore.queue(FamilyTree.FOCUS_MAILBOX_KEY, _selected_card.character)
	NavigationStore.go_to("res://Scenes/FamilyTree/family_tree.tscn")


## fallback_index:先前選取的角色已經不在新清單裡時(目前只有解雇會發生),要選哪一張
## 卡片頂替——傳入解雇前那個角色在清單裡的排序位置,讓選取自然滑到「下一位」(遞補上來
## 頂替原本位置的角色),而不是每次都跳回清單第一張。
func _refresh_grid(fallback_index: int = 0) -> void:
	_update_roster_title()
	var previously_selected_character: Character = _selected_card.character if _selected_card != null else null
	for child in roster_grid.get_children():
		roster_grid.remove_child(child)
		child.queue_free()
	_selected_card = null

	var characteres := sort_filter_bar.filter.apply(CharacterRosterStore.all_characteres)
	var new_cards: Array[CharacterAvatarCard] = []
	for character in characteres:
		var card := CharacterAvatarCard.new(character)
		card.character_selected.connect(_on_character_selected)
		roster_grid.add_child(card)
		new_cards.append(card)
		if character == previously_selected_character:
			_select_card(card)

	if _selected_card == null and not new_cards.is_empty():
		_select_card(new_cards[clampi(fallback_index, 0, new_cards.size() - 1)])
	elif _selected_card == null:
		_detail_view.set_character(null)
		_update_action_buttons()


## 標題附上目前角色數/上限,跟 base_action_panel.gd 住宅區「目前角色數」同一組數字
## (AllCharacterStore.all_characteres.size() / BaseBuildingProgressStore.
## get_character_capacity())——上限是全角色池的容量,不是這裡篩選後的顯示數量。
func _update_roster_title() -> void:
	var current := AllCharacterStore.all_characteres.size()
	var capacity := BaseBuildingProgressStore.get_character_capacity()
	roster_title.text = "全部角色 (%d/%d)" % [current, capacity]


func _on_character_selected(character: Character) -> void:
	for child in roster_grid.get_children():
		if child is CharacterAvatarCard and child.character == character:
			_select_card(child)
			return


func _select_card(card: CharacterAvatarCard) -> void:
	if _selected_card != null:
		_selected_card.selected = false
	_selected_card = card
	_selected_card.selected = true
	_detail_view.set_character(_selected_card.character)
	_update_action_buttons()


## 沒有任何角色被選取時(例如角色列表整個被解雇光了)「解雇」/「觀看祖譜」都沒有
## 對象可以操作,兩顆按鈕一起反灰。「解雇」對主角/目前隊長刻意不反灰——按下去要能
## 觸發 _on_dismiss_pressed() 跳 MessageBar 提示告知原因,反灰的話按鈕不會發出
## pressed 訊號,玩家點了會沒有任何反應,不知道是「不能解雇」還是「按鈕壞了」。
func _update_action_buttons() -> void:
	var has_selection := _selected_card != null
	dismiss_button.disabled = not has_selection
	view_family_tree_button.disabled = not has_selection
