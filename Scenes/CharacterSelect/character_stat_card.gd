class_name CharacterStatCard
extends PanelContainer

# =========================================================
# 根據地資源派遣選人清單用的卡片:大頭像(可另外點擊開 CharacterPanel,靠子節點
# MOUSE_FILTER_STOP 先吃掉事件擋掉冒泡,同 battle_party_roster.gd 頭像框的既有寫法)+
# 右側 label:value 兩欄小表,不可指派時整卡半透明 + tooltip 顯示原因、點擊無反應。跟
# CharacterAvatarCard 一樣具備 character/selected/character_selected 的形狀,可以互換
# 塞進 CharacterSelectBar 的 card_factory,見該檔案開頭註解。
# =========================================================

signal character_selected(character: Character)

const FACE_SIZE := Vector2(128, 128)

var character: Character
var selected: bool = false

var _stat_rows: Array
var _available: bool
var _unavailable_reason: String


func _init(p_character: Character, stat_rows: Array, p_available: bool = true, p_unavailable_reason: String = "") -> void:
	character = p_character
	_stat_rows = stat_rows
	_available = p_available
	_unavailable_reason = p_unavailable_reason


func _ready() -> void:
	add_theme_stylebox_override("panel", UiStyle.parchment_row_style(UiStyle.PARCHMENT_ROW_BORDER, 1, 8, 10.0, 6.0))
	mouse_filter = Control.MOUSE_FILTER_STOP

	if _available:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		gui_input.connect(_on_gui_input)
	else:
		modulate.a = 0.45
		tooltip_text = _unavailable_reason

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	add_child(content)

	var face_wrapper := CenterContainer.new()
	face_wrapper.custom_minimum_size = FACE_SIZE
	face_wrapper.mouse_filter = Control.MOUSE_FILTER_STOP
	face_wrapper.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	face_wrapper.gui_input.connect(_on_face_gui_input)
	content.add_child(face_wrapper)

	var face := TextureRect.new()
	face.custom_minimum_size = FACE_SIZE
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_SCALE
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not character.face_path.is_empty():
		face.texture = load(character.face_path) as Texture2D
	face_wrapper.add_child(face)

	var stat_grid := GridContainer.new()
	stat_grid.columns = 2
	stat_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat_grid.add_theme_constant_override("h_separation", 12)
	stat_grid.add_theme_constant_override("v_separation", 2)
	content.add_child(stat_grid)

	for row in _stat_rows:
		_add_stat_grid_row(stat_grid, row[0], row[1])


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		character_selected.emit(character)


func _on_face_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		CharacterPanel.open_for_character(character)
		get_viewport().set_input_as_handled()


func _add_stat_grid_row(stat_grid: GridContainer, label_text: String, value_text: String) -> void:
	var label := Label.new()
	label.text = label_text
	label.add_theme_color_override("font_color", UiStyle.PARCHMENT_SUBTITLE_COLOR)
	stat_grid.add_child(label)

	var value_label := Label.new()
	value_label.text = value_text
	value_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	stat_grid.add_child(value_label)
