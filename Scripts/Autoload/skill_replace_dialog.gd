extends CanvasLayer

# =========================================================
# 角色技能已滿(Character.MAX_SKILLS)時彈出的全域確認框(autoload,見 project.godot)。
# 外殼比照 AskBattle(Scenes/BattleUtil/ask_battle.gd)的公式——DimBg 全螢幕遮罩 +
# CenterContainer + PanelContainer(UiStyle.apply_parchment_panel()),但這裡全部用程式碼
# 在 _ready() 組節點,不另外寫 .tscn(比照 BarracksExpeditionStore 等純 .gd autoload 的
# 慣例)。layer 設 40,高於 CharacterSelectOverlay 的 30,確保疊在任何既有選人疊加層之上
# 都看得到——傳授/隊長訓練/歷練收成三個呼叫點都可能在別的疊加畫面上觸發。
#
# 替換/放棄兩個結果都由這裡直接完成 skill_list 異動,呼叫端(SkillLearnFlow)只需要處理
# on_result(applied: bool) 的後續(扣款/清狀態/重繪),不用自己碰 skill_list。
# =========================================================

const PANEL_WIDTH := 480.0
const PANEL_HEIGHT := 400.0

var root: Control
var _content: VBoxContainer
var _character: Character
var _new_skill: Skill
var _on_result: Callable


func _ready() -> void:
	layer = 40

	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.visible = false
	add_child(root)

	var dim_bg := ColorRect.new()
	dim_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim_bg.color = Color(0, 0, 0, 0.55)
	root.add_child(dim_bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var panel_box := PanelContainer.new()
	panel_box.custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	UiStyle.apply_parchment_panel(panel_box, PANEL_WIDTH, PANEL_HEIGHT)
	center.add_child(panel_box)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 12)
	panel_box.add_child(_content)


## character 技能已滿時彈出,列出目前技能各自的「替換」鈕 + 一顆「放棄學習」鈕。
## on_result(applied: bool) 替換成功傳 true,放棄傳 false。
func ask(character: Character, new_skill: Skill, on_result: Callable = Callable()) -> void:
	_character = character
	_new_skill = new_skill
	_on_result = on_result

	for child in _content.get_children():
		child.queue_free()

	var question := Label.new()
	question.text = "%s 的技能已滿（上限 %d 個），要學會下方新技能需要替換掉一個現有技能，或放棄學習。" % [
		character.display_name, Character.MAX_SKILLS
	]
	question.autowrap_mode = TextServer.AUTOWRAP_WORD
	question.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	_content.add_child(question)

	var new_skill_label := Label.new()
	new_skill_label.text = "新技能："
	new_skill_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	_content.add_child(new_skill_label)

	var new_skill_row := CenterContainer.new()
	new_skill_row.add_child(_build_skill_chip(new_skill))
	_content.add_child(new_skill_row)

	var replace_label := Label.new()
	replace_label.text = "點擊下方要替換掉的技能："
	replace_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	_content.add_child(replace_label)

	var grid := GridContainer.new()
	grid.columns = CharacterDetailView.SKILL_GRID_COLUMNS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for i in range(character.skill_list.size()):
		grid.add_child(_build_replace_slot(i))
	_content.add_child(grid)

	var give_up_button := Button.new()
	give_up_button.text = "放棄學習"
	UiStyle.apply_wood_plaque_button(give_up_button, 16.0, 8.0)
	give_up_button.pressed.connect(func() -> void:
		_close()
		if _on_result.is_valid():
			_on_result.call(false)
	)
	_content.add_child(give_up_button)

	root.visible = true


## 技能格共用外觀:沿用 CharacterDetailView 的 SKILL_SLOT_* 常數,跟角色詳情頁「技能」分頁的
## 格子同一套視覺,滑過去用 tooltip_text 顯示技能說明——「新技能」預覽格(ask() 頂部)跟下方
## 「現有技能(點擊替換)」格外觀統一共用這支,不要把新技能名稱純文字塞進句子裡(見 CLAUDE.md
## 這次需求)。
func _build_skill_chip(skill: Skill) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = CharacterDetailView.SKILL_SLOT_MIN_SIZE
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slot.add_theme_stylebox_override("panel", UiStyle.bordered_panel(
		CharacterDetailView.SKILL_SLOT_BG, CharacterDetailView.SKILL_SLOT_BORDER, 2, 6
	))

	var label := Label.new()
	label.text = "[%s] %s" % [GameEnums.rank_label(skill.rank), skill.name]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_font_size_override("font_size", 13)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(label)

	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.tooltip_text = "【%s】\n%s" % [skill.tag_label(), skill.description]
	return slot


## 整格點擊即直接替換,不再另外排一顆獨立的「替換」鈕。
func _build_replace_slot(index: int) -> Control:
	var skill: Skill = _character.skill_list[index]
	var slot := _build_skill_chip(skill)
	slot.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	slot.tooltip_text = "【%s】\n%s\n\n點擊替換為「%s」" % [skill.tag_label(), skill.description, _new_skill.name]
	slot.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_character.skill_list[index] = _new_skill
			_close()
			if _on_result.is_valid():
				_on_result.call(true)
	)

	return slot


func _close() -> void:
	root.visible = false
