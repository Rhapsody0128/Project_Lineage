class_name CharacterAvatarCard
extends Button

# =========================================================
# 角色列表畫面(CharacterRoster)下方網格的一張卡片:只顯示頭像,
# 不像 PartyEdit 的 CharacterCard 那樣還帶名字/battle_cost 形狀——名字
# 改用 tooltip 顯示。點擊後 character_selected 訊號通知上層換顯示的
# 角色,選中的卡片邊框變色標記,比照 header_bar.gd 的按鈕樣式寫法。
# =========================================================

signal character_selected(character: Character)

const CARD_SIZE := Vector2(112, 112)

const _BG_COLOR := Color(0.13, 0.15, 0.21, 0.95)
const _BORDER_COLOR := Color(0.36, 0.4, 0.56, 1)
const _SELECTED_BORDER_COLOR := Color(0.95, 0.75, 0.4, 1)

var character: Character

var selected: bool = false:
	set(value):
		selected = value
		_apply_style()


func _init(p_character: Character = null) -> void:
	character = p_character


func _ready() -> void:
	custom_minimum_size = CARD_SIZE
	expand_icon = true
	if character != null:
		tooltip_text = character.full_name
		if not character.face_path.is_empty():
			icon = load(character.face_path) as Texture2D
	_apply_style()
	pressed.connect(func(): character_selected.emit(character))


func _apply_style() -> void:
	var border_color := _SELECTED_BORDER_COLOR if selected else _BORDER_COLOR
	var border_width := 4 if selected else 2
	var style := UiStyle.bordered_panel(_BG_COLOR, border_color, border_width, 8)
	add_theme_stylebox_override("normal", style)
	add_theme_stylebox_override("hover", UiStyle.bordered_panel(_BG_COLOR, _SELECTED_BORDER_COLOR, border_width, 8))
	add_theme_stylebox_override("pressed", UiStyle.bordered_panel(_BG_COLOR, _SELECTED_BORDER_COLOR, border_width, 8))
	add_theme_stylebox_override("focus", style)
