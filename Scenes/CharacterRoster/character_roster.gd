extends Control

# =========================================================
# 角色列表畫面:上方 1/4 顯示目前選取角色的詳細資訊(CharacterDetailView,
# 橫向排版,跟彈出式 CharacterPanel 共用同一顆元件),下方 3/4 是
# HeroRosterStore.all_heroes(玩家擁有的全部角色,不是 PartyStore 的
# 隊伍編成)的頭像卡片網格,排序/篩選比照 PartyEdit 候補清單共用
# HeroSortFilterBar + System 層的 HeroSortFilter。點卡片切換上方顯示。
# =========================================================

@onready var detail_margin: MarginContainer = $VBox/DetailPanel/DetailMargin
@onready var sort_filter_bar: HeroSortFilterBar = $VBox/BottomPanel/BottomMargin/BottomVBox/SortFilterBar
@onready var roster_grid: HFlowContainer = $VBox/BottomPanel/BottomMargin/BottomVBox/ScrollContainer/RosterGrid

var _detail_view: CharacterDetailView
var _selected_card: CharacterAvatarCard


func _ready() -> void:
	_detail_view = CharacterDetailView.new()
	_detail_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_margin.add_child(_detail_view)

	sort_filter_bar.changed.connect(_refresh_grid)
	_refresh_grid()


func _on_back_pressed() -> void:
	NavigationStore.go_back()


func _refresh_grid() -> void:
	var previously_selected_hero: Hero = _selected_card.hero if _selected_card != null else null
	for child in roster_grid.get_children():
		child.queue_free()
	_selected_card = null

	var heroes := sort_filter_bar.filter.apply(HeroRosterStore.all_heroes)
	for hero in heroes:
		var card := CharacterAvatarCard.new(hero)
		card.hero_selected.connect(_on_hero_selected)
		roster_grid.add_child(card)
		if hero == previously_selected_hero:
			_select_card(card)

	if _selected_card == null and not heroes.is_empty():
		_select_card(roster_grid.get_child(0))
	elif _selected_card == null:
		_detail_view.set_hero(null)


func _on_hero_selected(hero: Hero) -> void:
	for child in roster_grid.get_children():
		if child is CharacterAvatarCard and child.hero == hero:
			_select_card(child)
			return


func _select_card(card: CharacterAvatarCard) -> void:
	if _selected_card != null:
		_selected_card.selected = false
	_selected_card = card
	_selected_card.selected = true
	_detail_view.set_hero(_selected_card.hero)
