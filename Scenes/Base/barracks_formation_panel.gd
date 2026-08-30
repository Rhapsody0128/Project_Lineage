class_name BarracksFormationPanel
extends HBoxContainer

# =========================================================
# 兵營「變換隊形」獨立畫面(ActionPanel.open_custom() 開的全新內容,見 barracks_panel.gd
# 的 _open_formation_panel())。左側 CharacterDetailView,右側上方是金錢存量 + 說明用的
# HINT 文字(花費金額不塞進按鈕文字,兩顆重抽鈕改放到標題列 × 鈕旁邊,見
# ActionPanel.set_title_action_button())+ 個人佔位形狀預覽並排目前整隊隊伍站位唯讀預覽
# (BarracksFormationPartyBoard),右下角是角色清單(CharacterSelectBar,跟角色選擇同一頁,
# 不再另開 CharacterSelectOverlay),點卡片直接切換目前調整對象。開頁當下預設選第一位
# 角色,CharacterDetailView 不會空著。跟學技能無關,不經過 SkillLearnFlow,不需要
# setup(building)——這裡不吃兵營等級限制。
#
# 已編入小隊(PartyStore.grid.is_placed())的角色不能在這裡變換隊形(重抽形狀/重抽佔位/
# E、Q 旋轉全部擋掉)——PartyEditGrid.place() 當初存進網格的形狀是「放置當下」的快照
# (見 party_edit_availability_layer.gd 的 _drop_data()),不是即時參照 Character.battle_cost,
# 這裡如果還讓玩家改動角色的 battle_cost,網格裡記錄的佔用格子會跟角色實際形狀兜不起來,
# 變成兩邊資料對不上的 BUG(見 CLAUDE.md 這次需求)。要變換隊形得先在小隊編成畫面把這個人
# 移出小隊。
#
# 旋轉個人佔位形狀(E 順時針/Q 逆時針)沿用 BattleCost.rotate_cw()/rotate_ccw()——跟
# party_edit.gd 的 _unhandled_key_input() 同一套旋轉數學,差別是那邊只轉動「拖曳中的預覽」
# 不落地,這裡是直接、免費地永久旋轉 Character.battle_cost 本身(不像重抽要花錢,單純換個
# 朝向不算重新抽形狀)。
# =========================================================

var _character: Character = null

var _detail_view: CharacterDetailView
var _gold_label: RichTextLabel
var _function_body: VBoxContainer
var _select_bar: CharacterSelectBar


func _ready() -> void:
	add_theme_constant_override("separation", 16)
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var detail_panel := PanelContainer.new()
	detail_panel.add_theme_stylebox_override("panel", UiStyle.right_border_style())
	add_child(detail_panel)

	_detail_view = CharacterDetailView.new()
	_detail_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_view.scrollable_tabs = false
	detail_panel.add_child(_detail_view)

	var right_column := VBoxContainer.new()
	right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_column.add_theme_constant_override("separation", 16)
	add_child(right_column)

	var top_panel := PanelContainer.new()
	top_panel.add_theme_stylebox_override("panel", UiStyle.bottom_border_style())
	right_column.add_child(top_panel)

	var top_column := VBoxContainer.new()
	top_column.add_theme_constant_override("separation", 10)
	top_panel.add_child(top_column)

	_gold_label = RichTextLabel.new()
	_gold_label.bbcode_enabled = true
	_gold_label.fit_content = true
	_gold_label.scroll_active = false
	_gold_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_gold_label.add_theme_color_override("default_color", UiStyle.PARCHMENT_TEXT_COLOR)
	top_column.add_child(_gold_label)

	_function_body = VBoxContainer.new()
	_function_body.add_theme_constant_override("separation", 12)
	top_column.add_child(_function_body)

	var picker_panel := PanelContainer.new()
	picker_panel.add_theme_stylebox_override("panel", UiStyle.transparent_panel_style())
	picker_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_column.add_child(picker_panel)

	var picker_column := VBoxContainer.new()
	picker_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	picker_column.add_theme_constant_override("separation", 10)
	picker_panel.add_child(picker_column)

	var picker_title := Label.new()
	picker_title.text = "全部角色"
	picker_title.add_theme_font_size_override("font_size", 18)
	picker_title.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	picker_column.add_child(picker_title)

	_select_bar = CharacterSelectBar.new()
	picker_column.add_child(_select_bar)

	var roster: Array[Character] = []
	for character in CharacterRosterStore.all_characteres:
		if not character.is_disabled:
			roster.append(character)
	if not roster.is_empty():
		_character = roster[0]
		_detail_view.set_character(_character)

	_select_bar.character_selected.connect(_on_list_card_selected)
	_select_bar.setup(roster, _avatar_card, -1, false)
	_select_bar.set_selected(_character)

	_rebuild_function()


## 已編入小隊的角色不能變換隊形(見上方檔頭註解,規則判斷收斂在 FormationRerollRule)。
func _is_locked_by_party() -> bool:
	return _character != null and not FormationRerollRule.can_reroll(_character)


func _rebuild_function() -> void:
	var gold_icon := "[img=20x20]%s[/img]" % GameEnums.resource_type_icon_path(GameEnums.ResourceType.GOLD)
	_gold_label.text = "目前金錢：%s %d" % [gold_icon, BaseResourceStore.get_display_amount(GameEnums.ResourceType.GOLD)]

	for child in _function_body.get_children():
		child.queue_free()

	var hint := RichTextLabel.new()
	hint.bbcode_enabled = true
	hint.fit_content = true
	hint.scroll_active = false
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	hint.custom_minimum_size = Vector2(360, 0)
	hint.add_theme_color_override("default_color", UiStyle.PARCHMENT_TEXT_COLOR)
	hint.text = "重抽形狀花費 %s %d，重抽佔位花費 %s %d，按鈕在右上角。個人佔位形狀可按 E／Q 旋轉方向。" % [
		gold_icon, FormationRerollRule.SHAPE_REROLL_COST, gold_icon, FormationRerollRule.ANCHOR_REROLL_COST
	]
	_function_body.add_child(hint)

	if _character != null and _is_locked_by_party():
		_function_body.add_child(_build_hint_label(
			"%s 已編入小隊，需先在小隊編成畫面移出才能變換隊形（重抽/旋轉都會讓小隊記錄的站位跟角色形狀對不上）。" % _character.display_name
		))

	ActionPanel.set_title_action_button(_build_title_buttons())

	if _character == null:
		return

	var preview_row := HBoxContainer.new()
	preview_row.add_theme_constant_override("separation", 24)
	_function_body.add_child(preview_row)

	var shape_column := VBoxContainer.new()
	shape_column.add_theme_constant_override("separation", 6)
	preview_row.add_child(shape_column)

	var shape_title := Label.new()
	shape_title.text = "個人佔位形狀"
	shape_title.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	shape_column.add_child(shape_title)

	var preview := BattleCostView.new()
	preview.cell_size = 32.0
	preview.weapon = _character.weapon
	preview.battle_cost = _character.battle_cost
	preview.custom_minimum_size = Vector2(200, 200)
	shape_column.add_child(preview)

	var party_column := VBoxContainer.new()
	party_column.add_theme_constant_override("separation", 6)
	preview_row.add_child(party_column)

	var party_title := Label.new()
	party_title.text = "目前隊伍站位（唯讀）"
	party_title.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	party_column.add_child(party_title)
	party_column.add_child(BarracksFormationPartyBoard.new())


## 顏色統一用 UiStyle.PARCHMENT_TEXT_COLOR,不額外疊警示色——整個兵營系列畫面(含
## CharacterDetailView)都是同一套文字顏色,不要有的地方特別換色(見 CLAUDE.md 這次需求)。
func _build_hint_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	return label


## 兩顆重抽鈕移到標題列(× 鈕旁邊,見 CLAUDE.md 這次需求),不再擠在內容區塊裡跟花費文字
## 綁在一起——每次 _rebuild_function() 都重新組一份,直接靠 set_title_action_button() 的
## 「傳新的會自動清掉舊的」語意汰換,不用額外持有參照手動更新 disabled 狀態。已編入小隊時
## 兩顆都整個擋掉(見 _is_locked_by_party())。
func _build_title_buttons() -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var locked := _is_locked_by_party()

	var shape_button := Button.new()
	shape_button.text = "重抽形狀"
	UiStyle.style_panel_action_button(shape_button)
	shape_button.tooltip_text = "已編入小隊，無法變換隊形" if locked else "花費 %d 金錢" % FormationRerollRule.SHAPE_REROLL_COST
	shape_button.disabled = (
		locked or _character == null
		or not BaseResourceStore.can_afford({GameEnums.ResourceType.GOLD: FormationRerollRule.SHAPE_REROLL_COST})
	)
	shape_button.pressed.connect(func() -> void:
		BaseResourceStore.spend({GameEnums.ResourceType.GOLD: FormationRerollRule.SHAPE_REROLL_COST})
		BattleCostController.reroll_shape(_character)
		_rebuild_function()
	)
	box.add_child(shape_button)

	var anchor_button := Button.new()
	anchor_button.text = "重抽佔位"
	UiStyle.style_panel_action_button(anchor_button)
	anchor_button.tooltip_text = "已編入小隊，無法變換隊形" if locked else "花費 %d 金錢" % FormationRerollRule.ANCHOR_REROLL_COST
	anchor_button.disabled = (
		locked or _character == null
		or not BaseResourceStore.can_afford({GameEnums.ResourceType.GOLD: FormationRerollRule.ANCHOR_REROLL_COST})
	)
	anchor_button.pressed.connect(func() -> void:
		BaseResourceStore.spend({GameEnums.ResourceType.GOLD: FormationRerollRule.ANCHOR_REROLL_COST})
		BattleCostController.reroll_anchor(_character)
		_rebuild_function()
	)
	box.add_child(anchor_button)

	return box


## E 順時針／Q 逆時針,免費立即旋轉目前角色的佔位形狀本身(不是拖曳預覽)——邏輯沿用
## party_edit.gd 的同一套 BattleCost.rotate_cw()/rotate_ccw()。已編入小隊時不生效(見
## _is_locked_by_party()),避免跟小隊裡記錄的站位形狀兜不起來。
func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode != KEY_E and event.keycode != KEY_Q:
		return
	if _character == null or _is_locked_by_party():
		return

	_character.battle_cost = _character.battle_cost.rotate_cw() if event.keycode == KEY_E else _character.battle_cost.rotate_ccw()
	_rebuild_function()
	get_viewport().set_input_as_handled()


func _on_list_card_selected(character: Character) -> void:
	_character = character
	_detail_view.set_character(character)
	_select_bar.set_selected(character)
	_rebuild_function()


## 已編入小隊、不能變換隊形的角色卡片視覺上一樣反灰(force_dim),但仍可點選查看——只是
## 選中後右上角兩顆重抽鈕會整個 disabled(見 _build_title_buttons())。
func _avatar_card(character: Character) -> Control:
	var locked := not FormationRerollRule.can_reroll(character)
	var reason := "已編入小隊，無法變換隊形" if locked else ""
	return CharacterAvatarCard.new(character, true, reason, locked)
