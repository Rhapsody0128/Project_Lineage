class_name MarketPanelContent
extends VBoxContainer

## 城鎮市集彈出面板的內容(外殼共用 Scenes/ActionPanel/action_panel.gd 的
## open_custom(),比照 Scenes/Base/base_action_panel.gd 的 BaseBuildingPanelContent
## 寫法)——不切場景,map_location.gd 的市集按鈕直接呼叫 ActionPanel.open_custom() 疊加
## 顯示,見該檔案 CLAUDE.md「共用 UI」節的彈出面板慣例。
##
## 定價規則見 System/base/market.gd 的 Market:只能用金錢/贓物買資材,不能賣;單價比
## 根據地貿易(商隊站/黑市,見 System/base/base_exchange.gd)基準價貴,好感度等級愈高
## 加價倍率愈低,但保證恆比貿易基準價貴。TabContainer 分頁只有「資材」接了真實購買邏輯,
## 「特殊道具」先開分頁佔位(尚未設計),不接任何商品清單。

const RESOURCE_ICON_SIZE := Vector2(28, 28)
const QUICK_BUY_QUANTITIES: Array[int] = [1, 10]

## 分頁內容跟 TabContainer 邊緣的內距,比照
## Scenes/CharacterPanel/character_detail_view.gd 的 TAB_CONTENT_PADDING。
const TAB_CONTENT_PADDING := 14

var _nation: int
var _materials_list: VBoxContainer


func _init(p_nation: int) -> void:
	_nation = p_nation


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	_add_label(_build_header_text())

	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(0, 420)
	_style_tabs(tabs)
	add_child(tabs)

	_materials_list = VBoxContainer.new()
	_materials_list.add_theme_constant_override("separation", 8)
	tabs.add_child(_wrap_tab_content("資材", _materials_list))

	var special_items_tab := VBoxContainer.new()
	var placeholder := Label.new()
	placeholder.text = "尚未開放"
	placeholder.add_theme_color_override("font_color", UiStyle.PARCHMENT_SUBTITLE_COLOR)
	special_items_tab.add_child(placeholder)
	tabs.add_child(_wrap_tab_content("特殊道具", special_items_tab))

	_refresh_materials()


## 分頁籤外觀比照 CharacterDetailView._ready():TabContainer 本身不疊底色(彈出面板的
## 羊皮紙底已經是背景),分頁籤用木框/羊皮紙描邊區分選中/未選中/滑過,不用引擎預設的
## 深色系統風格。
func _style_tabs(tabs: TabContainer) -> void:
	tabs.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	tabs.add_theme_stylebox_override("tab_selected", UiStyle.bordered_panel(
		Color(0.85, 0.72, 0.5, 0.6), UiStyle.PARCHMENT_ROW_BORDER, 1, 8, 10.0, 6.0
	))
	tabs.add_theme_stylebox_override("tab_unselected", UiStyle.bordered_panel(
		Color(0.55, 0.42, 0.26, 0.12), Color(0, 0, 0, 0), 0, 8, 10.0, 6.0
	))
	tabs.add_theme_stylebox_override("tab_hovered", UiStyle.bordered_panel(
		Color(0.7, 0.55, 0.35, 0.35), UiStyle.PARCHMENT_ROW_BORDER, 1, 8, 10.0, 6.0
	))
	tabs.add_theme_color_override("font_selected_color", UiStyle.PARCHMENT_TEXT_COLOR)
	tabs.add_theme_color_override("font_unselected_color", UiStyle.PARCHMENT_SUBTITLE_COLOR)
	tabs.add_theme_color_override("font_hovered_color", UiStyle.PARCHMENT_TEXT_COLOR)


func _wrap_tab_content(tab_name: String, content: Control) -> Control:
	var margin := MarginContainer.new()
	margin.name = tab_name
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, TAB_CONTENT_PADDING)
	margin.add_child(content)
	return margin


func _build_header_text() -> String:
	return "只能用金錢／贓物購買資材,不能販售。資材價格恆比根據地貿易（商隊站／黑市）貴,對%s好感度愈高加價愈少。" % GameEnums.bloodline_nation_label(_nation)


func _favor_rank() -> int:
	return NationFavorRank.rank_for_favor(NationFavorStore.get_favor(_nation))


func _refresh_materials() -> void:
	for child in _materials_list.get_children():
		child.queue_free()

	var balance_label := Label.new()
	balance_label.text = "目前持有：金錢 %d　贓物 %d　（好感度等級 %s）" % [
		BaseResourceStore.get_amount(GameEnums.ResourceType.GOLD),
		BaseResourceStore.get_amount(GameEnums.ResourceType.CONTRABAND),
		GameEnums.rank_label(_favor_rank()),
	]
	balance_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	_materials_list.add_child(balance_label)

	for option in Market.options():
		_materials_list.add_child(_build_material_row(option))


func _build_material_row(option: Market.MarketOption) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	row.add_child(_build_resource_icon(option.resource))

	var name_label := Label.new()
	name_label.text = GameEnums.resource_string_label(option.resource)
	name_label.custom_minimum_size = Vector2(80, 0)
	name_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	row.add_child(name_label)

	var owned_label := Label.new()
	owned_label.text = "現有 %d" % BaseResourceStore.get_amount(option.resource)
	owned_label.custom_minimum_size = Vector2(70, 0)
	owned_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_SUBTITLE_COLOR)
	row.add_child(owned_label)

	var favor_rank := _favor_rank()
	var price := Market.unit_price(option.base_unit_price, favor_rank)

	var price_row := HBoxContainer.new()
	price_row.add_theme_constant_override("separation", 2)
	price_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var price_label := Label.new()
	price_label.text = "單價 %d" % price
	price_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_SUBTITLE_COLOR)
	price_row.add_child(price_label)
	price_row.add_child(_build_resource_icon(option.currency))
	row.add_child(price_row)

	for quantity in QUICK_BUY_QUANTITIES:
		row.add_child(_build_buy_button(option, price, quantity))

	return row


## 倉庫放不下這整筆數量時直接不給按(不扣錢、不部分成交)——比照 BaseResourceStore.
## remaining_capacity() 的用法說明,買之前就擋下來,不要讓玩家花了錢卻因為倉庫上限
## 被吃掉一部分資材。
func _build_buy_button(option: Market.MarketOption, price: int, quantity: int) -> Button:
	var button := Button.new()
	button.text = "購買 x%d" % quantity
	UiStyle.apply_wood_plaque_button(button, 12.0, 4.0)
	button.add_theme_font_size_override("font_size", 14)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	var cost := price * quantity
	var remaining := BaseResourceStore.remaining_capacity(option.resource)
	var fits_warehouse := remaining < 0 or quantity <= remaining
	var affordable := BaseResourceStore.can_afford({option.currency: cost})
	button.disabled = not affordable or not fits_warehouse
	if not fits_warehouse:
		button.tooltip_text = "倉庫空間不足,無法購買"
	elif not affordable:
		button.tooltip_text = "%s不足" % GameEnums.resource_string_label(option.currency)

	button.pressed.connect(func() -> void:
		BaseResourceStore.spend({option.currency: cost})
		BaseResourceStore.add(option.resource, quantity)
		_refresh_materials()
	)
	return button


func _build_resource_icon(resource_type: int) -> TextureRect:
	var icon := TextureRect.new()
	icon.custom_minimum_size = RESOURCE_ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = load(GameEnums.resource_type_icon_path(resource_type)) as Texture2D
	icon.tooltip_text = GameEnums.resource_string_label(resource_type)
	return icon


func _add_label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	add_child(label)
