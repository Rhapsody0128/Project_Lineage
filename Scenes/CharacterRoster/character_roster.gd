extends Control

# =========================================================
# 角色列表畫面:左側固定寬度(DetailPanel custom_minimum_size,跟
# character_panel.tscn 的 PanelBox 同寬,兩處視覺尺寸一致)顯示目前選取
# 角色的詳細資訊(CharacterDetailView,直式排版,跟彈出式 CharacterPanel
# 共用同一顆元件),右側 RosterPanel 自動撐滿剩餘寬度,是
# CharacterRosterStore.all_characteres(玩家擁有的全部角色,不是 PartyStore 的
# 隊伍編成)的頭像卡片網格,排序/篩選比照 PartyEdit 候補清單共用
# CharacterSortFilterBar + System 層的 CharacterSortFilter。點卡片切換左側顯示。
# =========================================================

@onready var detail_margin: MarginContainer = $MainRow/DetailPanel/DetailMargin
@onready var sort_filter_bar: CharacterSortFilterBar = $MainRow/RosterPanel/RosterMargin/RosterVBox/SortFilterBar
@onready var roster_grid: HFlowContainer = $MainRow/RosterPanel/RosterMargin/RosterVBox/ScrollContainer/RosterGrid
@onready var back_button: Button = $TopBar/BackButton

var _detail_view: CharacterDetailView
var _selected_card: CharacterAvatarCard


func _ready() -> void:
	UiStyle.apply_wood_plaque_button(back_button, 16.0, 8.0)
	back_button.add_theme_font_size_override("font_size", 18)

	_detail_view = CharacterDetailView.new()
	_detail_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_margin.add_child(_detail_view)

	sort_filter_bar.changed.connect(_refresh_grid)
	_refresh_grid()


func _on_back_pressed() -> void:
	NavigationStore.go_back()


func _refresh_grid() -> void:
	var previously_selected_character: Character = _selected_card.character if _selected_card != null else null
	for child in roster_grid.get_children():
		child.queue_free()
	_selected_card = null

	var characteres := sort_filter_bar.filter.apply(CharacterRosterStore.all_characteres)
	for character in characteres:
		var card := CharacterAvatarCard.new(character)
		card.character_selected.connect(_on_character_selected)
		roster_grid.add_child(card)
		if character == previously_selected_character:
			_select_card(card)

	if _selected_card == null and not characteres.is_empty():
		_select_card(roster_grid.get_child(0))
	elif _selected_card == null:
		_detail_view.set_character(null)


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
