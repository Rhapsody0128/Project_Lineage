class_name WeaponCraftPanel
extends VBoxContainer

# =========================================================
# 鐵匠鋪「打造武器」畫面(跟「變更武器」是分開的兩個獨立功能,見 Scenes/Base/
# base_action_panel.gd 的 _open_weapon_craft_panel())。固定綁一種武器類型——從主面板
# 總覽表格每列自己的「打造武器」鈕進入(見 base_action_panel.gd 的
# _add_forge_weapon_row()),不再有「先選類型」這一步,ActionPanel 標題本身已經顯示
# 「打造武器（武器名）」,畫面裡不用重複。
#
# 版面:最上面一列鐵礦庫存/打造花費/打造鈕(跨欄置頂,打造完立即刷新庫存數字、多按幾次
# 就能連續打造出好幾把候選,混在同一份候選網格裡);下面是候選卡片網格(HFlowContainer)
# ——每張卡片標頭列(武器名+新 rank)靠左、「替換」勾選框靠右上(同一列),下方沿用
# 「素質/目前/新武器/差異」四欄比較表(原本/現在/變化多少都看得到,比只列變動量的精簡版
# 更好讀)。同一類型的候選卡片共用同一個 ButtonGroup,勾選互斥,不會出現兩把都打勾的
# 不合理狀態(這個畫面現在固定只有一種類型,所以整個畫面共用一組就夠)。標題列「確定」鈕
# 一次套用打勾的那張(WeaponStore.equip()),沒打勾的視同捨棄。
# =========================================================

const _POSITIVE_COLOR := Color(0.16, 0.42, 0.16)
const _NEGATIVE_COLOR := Color(0.75, 0.25, 0.25)
## 武器主屬性(GameEnums.weapon_main_stat())在「素質」欄用這個顏色標記,例如捕夢網的
## 信仰列——跟差異欄的漲跌紅綠是各自獨立的用途,只是剛好共用同一個紅。
const _MAIN_STAT_COLOR := Color(0.75, 0.25, 0.25)
const _CARD_WIDTH := 320.0

var _weapon_type: int
var _stock_label: Label
var _card_grid: HFlowContainer
var _replace_group: ButtonGroup
var _on_close: Callable

## row: {candidate: WeaponInstance, checkbox: CheckBox}
var _pending: Array[Dictionary] = []


func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 16)

	_replace_group = ButtonGroup.new()

	add_child(_build_header_row())

	_card_grid = HFlowContainer.new()
	_card_grid.add_theme_constant_override("h_separation", 12)
	_card_grid.add_theme_constant_override("v_separation", 12)
	_card_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(ActionPanel.wrap_scrollable(_card_grid))

	var confirm_button := Button.new()
	confirm_button.text = "確定"
	UiStyle.style_panel_action_button(confirm_button)
	confirm_button.pressed.connect(_on_confirm_pressed)
	ActionPanel.set_title_action_button(confirm_button)


## 最上面一列:鐵礦庫存(打造完即時刷新)、每次打造花費、打造鈕。
func _build_header_row() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.bottom_border_style())

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)

	var ore_icon := TextureRect.new()
	ore_icon.custom_minimum_size = Vector2(26, 26)
	ore_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ore_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ore_icon.texture = load(GameEnums.resource_type_icon_path(GameEnums.ResourceType.ORE)) as Texture2D
	row.add_child(ore_icon)

	_stock_label = Label.new()
	_stock_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	row.add_child(_stock_label)

	var cost_label := Label.new()
	cost_label.text = "每次打造花費：%d 鐵礦" % _current_cost()
	cost_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_SUBTITLE_COLOR)
	row.add_child(cost_label)

	var craft_button := Button.new()
	craft_button.text = "打造"
	UiStyle.style_panel_action_button(craft_button)
	craft_button.pressed.connect(_on_craft_pressed)
	row.add_child(craft_button)

	return panel


func _refresh_stock_label() -> void:
	_stock_label.text = "鐵礦庫存：%d" % BaseResourceStore.get_display_amount(GameEnums.ResourceType.ORE)


## 依鐵匠鋪目前品階查表(WeaponLibrary.CRAFT_ORE_COST_BY_RANK),已套用「鍛造節約」
## 科技線的扣減——標題列顯示的花費跟按下「打造」實際扣的花費一定同一個數字。
func _current_cost() -> int:
	var base_rank := BaseBuildingProgressStore.get_rank(GameEnums.BuildingType.FORGE)
	return WeaponLibrary.craft_ore_cost(base_rank)


## 打造武器畫面唯一入口。weapon_type 固定這個畫面只能打造哪一種類型(見
## base_action_panel.gd 的 _add_forge_weapon_row())。on_close 簽名 func() -> void,
## 「確定」套用完畢後呼叫,交給呼叫端關閉 ActionPanel 並重開鐵匠鋪面板。
func setup(weapon_type: int, on_close: Callable) -> void:
	_weapon_type = weapon_type
	_on_close = on_close
	_refresh_stock_label()


func _on_craft_pressed() -> void:
	var base_rank := BaseBuildingProgressStore.get_rank(GameEnums.BuildingType.FORGE)
	var cost := {GameEnums.ResourceType.ORE: WeaponLibrary.craft_ore_cost(base_rank)}
	if not BaseResourceStore.can_afford(cost):
		MessageBar.show_message("資材不足")
		return
	BaseResourceStore.spend(cost)
	_refresh_stock_label()
	var candidate := WeaponLibrary.craft_weapon(_weapon_type, base_rank)
	_add_candidate_card(candidate)


func _add_candidate_card(candidate: WeaponInstance) -> void:
	var current: WeaponInstance = WeaponStore.get_equipped(_weapon_type)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(_CARD_WIDTH, 0)
	card.add_theme_stylebox_override("panel", UiStyle.parchment_row_style(UiStyle.PARCHMENT_ROW_BORDER, 1, 8, 10.0, 8.0, 4))

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	card.add_child(column)

	## 標頭列:武器名+新 rank 靠左,「替換」勾選框靠右上,同一列。
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	column.add_child(header)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(22, 22)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = load(GameEnums.weapon_icon_path(_weapon_type)) as Texture2D
	header.add_child(icon)

	var name_label := Label.new()
	name_label.text = "%s %s級" % [GameEnums.weapon_label(_weapon_type), GameEnums.rank_label(candidate.rank_type)]
	name_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)

	var checkbox := CheckBox.new()
	checkbox.text = "替換"
	checkbox.button_group = _replace_group
	header.add_child(checkbox)

	## 素質/目前/新武器/差異四欄比較表,原本/現在/變化多少都看得到。
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 4)
	for header_text in ["素質", "目前", "新武器", "差異"]:
		var cell := Label.new()
		cell.text = header_text
		cell.add_theme_color_override("font_color", UiStyle.PARCHMENT_SUBTITLE_COLOR)
		grid.add_child(cell)
	for potential_type in GameEnums.PotentialType.values():
		_add_compare_row(grid, potential_type, current, candidate)
	_add_total_row(grid, current, candidate)
	column.add_child(grid)

	_card_grid.add_child(card)
	_pending.append({"candidate": candidate, "checkbox": checkbox})


func _add_compare_row(grid: GridContainer, potential_type: int, current: WeaponInstance, candidate: WeaponInstance) -> void:
	var old_value := current.get_point(potential_type)
	var new_value := candidate.get_point(potential_type)
	var delta := new_value - old_value

	var name_label := Label.new()
	name_label.text = GameEnums.potential_label(potential_type)
	var is_main_stat := potential_type == GameEnums.weapon_main_stat(_weapon_type)
	name_label.add_theme_color_override("font_color", _MAIN_STAT_COLOR if is_main_stat else UiStyle.PARCHMENT_TEXT_COLOR)
	grid.add_child(name_label)

	var old_label := Label.new()
	old_label.text = str(old_value)
	old_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	grid.add_child(old_label)

	var new_label := Label.new()
	new_label.text = str(new_value)
	new_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	grid.add_child(new_label)

	var delta_label := Label.new()
	var delta_color := UiStyle.PARCHMENT_SUBTITLE_COLOR
	if delta > 0:
		delta_label.text = "+%d" % delta
		delta_color = _POSITIVE_COLOR
	elif delta < 0:
		delta_label.text = "%d" % delta
		delta_color = _NEGATIVE_COLOR
	else:
		delta_label.text = "-"
	delta_label.add_theme_color_override("font_color", delta_color)
	grid.add_child(delta_label)


## 六大素質列跑完後多加一列「總素質」,原本/現在/變化多少的算法跟單一素質列一致,只是
## 加總——不算主屬性標記對象(那個是六大素質各自的欄,不是總計)。
func _add_total_row(grid: GridContainer, current: WeaponInstance, candidate: WeaponInstance) -> void:
	var old_value := current.total_points()
	var new_value := candidate.total_points()
	var delta := new_value - old_value

	var name_label := Label.new()
	name_label.text = "總素質"
	name_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	grid.add_child(name_label)

	var old_label := Label.new()
	old_label.text = str(old_value)
	old_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	grid.add_child(old_label)

	var new_label := Label.new()
	new_label.text = str(new_value)
	new_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	grid.add_child(new_label)

	var delta_label := Label.new()
	var delta_color := UiStyle.PARCHMENT_SUBTITLE_COLOR
	if delta > 0:
		delta_label.text = "+%d" % delta
		delta_color = _POSITIVE_COLOR
	elif delta < 0:
		delta_label.text = "%d" % delta
		delta_color = _NEGATIVE_COLOR
	else:
		delta_label.text = "-"
	delta_label.add_theme_color_override("font_color", delta_color)
	grid.add_child(delta_label)


func _on_confirm_pressed() -> void:
	for entry in _pending:
		var checkbox: CheckBox = entry["checkbox"]
		if checkbox.button_pressed:
			WeaponStore.equip(_weapon_type, entry["candidate"])
	_on_close.call()
