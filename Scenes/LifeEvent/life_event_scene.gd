class_name LifeEventScene
extends Control

# =========================================================
# 新生兒命名 + 決定未來留學國家,合併成同一個全螢幕場景(取代原本 ActionPanel 疊加式的
# 兩個彈窗)。出生當下觸發(見 LifeEventQueueStore.queue_child()/System/time/
# world_time_event_library.gd 的 _deliver_child()),用 NavigationStore.go_to() 切過來
# ——這個場景沒有 HeaderBar,世界時間自動停止推進(見 CLAUDE.md「世界時間」章節既有
# 慣例),不用另外手動暫停。同一個月多個小孩同時出生時,LifeEventQueueStore 改用
# get_tree().reload_current_scene() 原地換下一個小孩重來一輪,不會疊出好幾層場景。
#
# 版面:左側 CharacterDetailView 顯示新生兒本人;右上命名輸入框(打字當下只更新畫面
# 文字預覽,見 _on_name_changed(),實際 Character.name 要等按下確認才寫入,空白時
# fallback 用出生當下已經抽好的隨機姓名);右下六國留學按鈕,文案刻意精簡(見
# AcademyRule.NATION_FLAVOR,是玩家視角的風味敘述,不是機制說明),選定後才能按確認。
# 確認時武器/技能一起換好(AcademyRule.enroll(),技能改用跟
# CharacterController.get_random_character() 相同的抽選邏輯,不是固定塞一支技能)。
# =========================================================

## 命名輸入寬度上限,以半形字元寬度為單位計算(全形字寬度算 2,半形算 1)——
## 4 格全形中文或 8 格半形英文,避免 CharacterDetailView 姓名欄爆版。
const MAX_NAME_WIDTH := 8

@onready var _content_root: Control = $Root

var _detail_view: CharacterDetailView
var _name_edit: LineEdit
var _confirm_button: Button
var _nation_button_group: ButtonGroup

var _character: Character
var _selected_nation: int = -1
var _nation_buttons: Dictionary = {}


func _ready() -> void:
	var handoff := SceneHandoffStore.take(LifeEventQueueStore.MAILBOX_KEY)
	_character = handoff.payload as Character if handoff != null else null

	_build_layout()

	if _character != null:
		_name_edit.text = _character.name
		_detail_view.set_character(_character)
		var default_nation := AcademyRule.nation_for_weapon(_character.weapon)
		if default_nation != -1:
			_select_nation(default_nation)


func _build_layout() -> void:
	var main_row := HBoxContainer.new()
	main_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_row.add_theme_constant_override("separation", 16)
	_content_root.add_child(main_row)

	var detail_panel := PanelContainer.new()
	main_row.add_child(detail_panel)

	_detail_view = CharacterDetailView.new()
	_detail_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.add_child(_detail_view)

	var panel_size := detail_panel.get_combined_minimum_size()
	UiStyle.apply_parchment_panel(detail_panel, panel_size.x, panel_size.y)

	var right_column := VBoxContainer.new()
	right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_column.add_theme_constant_override("separation", 16)
	main_row.add_child(right_column)

	right_column.add_child(_build_naming_panel())
	right_column.add_child(_build_nation_panel())

	var confirm_row := HBoxContainer.new()
	confirm_row.alignment = BoxContainer.ALIGNMENT_END
	right_column.add_child(confirm_row)

	_confirm_button = Button.new()
	_confirm_button.text = "確認"
	UiStyle.apply_wood_plaque_button(_confirm_button, 24.0, 10.0)
	_confirm_button.add_theme_font_size_override("font_size", 18)
	_confirm_button.disabled = true
	_confirm_button.pressed.connect(_on_confirm_pressed)
	confirm_row.add_child(_confirm_button)


func _build_naming_panel() -> Control:
	var panel := PanelContainer.new()
	UiStyle.apply_parchment_panel(panel, 700.0, 140.0)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	var title := Label.new()
	title.text = "命名"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	column.add_child(title)

	_name_edit = LineEdit.new()
	_name_edit.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	_name_edit.add_theme_stylebox_override("normal", UiStyle.bordered_panel(
		Color(1, 1, 1, 0.5), UiStyle.PARCHMENT_ROW_BORDER, 1, 8, 10.0, 6.0
	))
	_name_edit.text_changed.connect(_on_name_changed)
	column.add_child(_name_edit)

	return panel


func _build_nation_panel() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UiStyle.apply_parchment_panel(panel, 700.0, 460.0)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(column)

	var title := Label.new()
	title.text = "留學國家"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	column.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	column.add_child(grid)

	_nation_button_group = ButtonGroup.new()
	for nation in GameEnums.BloodlineNation.values():
		var button := _build_nation_button(nation)
		_nation_buttons[nation] = button
		grid.add_child(button)

	return panel


func _build_nation_button(nation: int) -> Button:
	var button := Button.new()
	button.text = "%s國\n%s" % [GameEnums.bloodline_nation_label(nation), AcademyRule.flavor_for_nation(nation)]
	button.toggle_mode = true
	button.button_group = _nation_button_group
	button.custom_minimum_size = Vector2(0, 70)
	UiStyle.apply_wood_plaque_button(button, 12.0, 6.0)
	button.add_theme_font_size_override("font_size", 15)
	button.pressed.connect(func() -> void: _on_nation_selected(nation))
	return button


func _on_name_changed(new_text: String) -> void:
	var truncated := _truncate_to_width(new_text, MAX_NAME_WIDTH)
	if truncated != new_text:
		_name_edit.text = truncated
		_name_edit.caret_column = truncated.length()
		return
	_detail_view.name_label.text = (
		"%s·%s" % [truncated, _character.last_name] if not truncated.is_empty() else _character.full_name
	)


## 全形字元(unicode 碼點 > 0xFF,涵蓋中日韓文字)算寬度 2,半形算寬度 1,
## 超過 max_width 就截斷——姓名輸入框不用內建 max_length(那是純字元數,無法區分全半形)。
static func _truncate_to_width(text: String, max_width: int) -> String:
	var width := 0
	var result := ""
	for i in text.length():
		var w := 2 if text.unicode_at(i) > 0xFF else 1
		if width + w > max_width:
			break
		width += w
		result += text[i]
	return result


func _on_nation_selected(nation: int) -> void:
	_selected_nation = nation
	_confirm_button.disabled = false


## 新生兒出生當下已依遺傳規則帶有 weapon(見 InheritanceController.create_child()),
## 預設幫玩家勾好對應國家按鈕(可再改選其他國家)。set button_pressed 只更新
## ButtonGroup 視覺狀態、不會觸發 pressed 訊號,因此手動呼叫 _on_nation_selected()
## 補上原本靠點擊觸發的狀態寫入。
func _select_nation(nation: int) -> void:
	var button: Button = _nation_buttons.get(nation)
	if button == null:
		return
	button.button_pressed = true
	_on_nation_selected(nation)


func _on_confirm_pressed() -> void:
	var new_name := _name_edit.text.strip_edges()
	if not new_name.is_empty():
		_character.name = new_name
	AcademyRule.enroll(_character, _selected_nation)
	LifeEventQueueStore.finish_current()
