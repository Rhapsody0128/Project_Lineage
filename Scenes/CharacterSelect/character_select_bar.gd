class_name CharacterSelectBar
extends VBoxContainer

# =========================================================
# 角色頭像網格 + 排序/篩選列的共用組合,取代 CharacterRoster/MarriageProposal/
# BaseBuildingPanelContent 各自重複的「排序列 + 卡片網格 + 選取狀態管理」寫法。不包自己的
# ScrollContainer——這裡的消費端(告白/聯姻面板、根據地資源派遣選人清單)都是塞進
# Scenes/CharacterSelect/character_select_panel.gd(CharacterSelectPanel)或
# Scripts/UI/fullscreen_overlay.gd(FullscreenOverlay)的內容,外殼本身已經給足版面空間,
# 這裡再包一層 ScrollContainer 沒有意義。
#
# card_factory 簽名 func(character: Character) -> Control,回傳的 Control 必須具備
# character: Character / selected: bool 兩個屬性,以及 character_selected(character) 訊號
# ——CharacterAvatarCard/CharacterStatCard 都符合這個形狀,這裡用 Object.set()/get()/
# connect() 的字串形式動態存取,不要求呼叫端回傳固定型別。
#
# 用法:比照 CharacterDetailView 的既有慣例,先 add_child(bar) 掛進場景樹(讓 _ready()
# 把內部的 _grid 建好),再呼叫 setup() 灌資料——不要顛倒順序。
# =========================================================

signal character_selected(character: Character)

var sort_filter_bar: CharacterSortFilterBar

var _grid: HFlowContainer
var _characters: Array[Character] = []
var _card_factory: Callable
var _selected_character: Character


func _ready() -> void:
	add_theme_constant_override("separation", 10)

	_grid = HFlowContainer.new()
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	add_child(_grid)


## initial_sort_key: -1 為不排序,其餘對應 GameEnums.CharacterSortKey(見
## CharacterSortFilterBar.configure())。sort_filter_bar 延到這裡才建立,是因為要在它
## _ready() 之前就把 configure() 的初始狀態設好。
func setup(characters: Array[Character], card_factory: Callable, initial_sort_key: int = -1, show_weapon_filter: bool = true) -> void:
	_characters = characters
	_card_factory = card_factory

	if sort_filter_bar == null:
		sort_filter_bar = CharacterSortFilterBar.new()
		sort_filter_bar.configure(initial_sort_key, show_weapon_filter)
		add_child(sort_filter_bar)
		move_child(sort_filter_bar, 0)
		sort_filter_bar.changed.connect(refresh)

	refresh()


func refresh() -> void:
	for child in _grid.get_children():
		child.queue_free()

	for character in sort_filter_bar.filter.apply(_characters):
		var card: Control = _card_factory.call(character)
		card.connect("character_selected", _on_card_selected)
		card.set("selected", character == _selected_character)
		_grid.add_child(card)


## 外部想強制指定目前高亮的卡片時用(例如告白面板一開始要預設高亮 courted)。
func set_selected(character: Character) -> void:
	_selected_character = character
	for card in _grid.get_children():
		card.set("selected", card.get("character") == character)


func _on_card_selected(character: Character) -> void:
	set_selected(character)
	character_selected.emit(character)
