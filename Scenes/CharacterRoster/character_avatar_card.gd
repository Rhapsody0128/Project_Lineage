class_name CharacterAvatarCard
extends Button

# =========================================================
# 角色列表畫面(CharacterRoster)下方網格的一張卡片:只顯示頭像,
# 不像 PartyEdit 的 CharacterCard 那樣還帶名字/battle_cost 形狀——名字
# 改用 tooltip 顯示。點擊後 character_selected 訊號通知上層換顯示的
# 角色,選中的卡片邊框變色標記,比照 header_bar.gd 的按鈕樣式寫法。
#
# available/unavailable_reason(選填,預設可選):給 Scenes/CharacterSelect/
# character_select_panel.gd 這類「選一位角色」情境共用——不可選時整卡半透明、
# disabled(點擊無反應)、tooltip 換成原因文字而不是姓名,取代原本
# Scenes/CharacterSelect/character_stat_card.gd 自己實作的同一套反灰邏輯
# (該檔案已刪除,完整素質資訊改由左側 CharacterDetailView 負責,卡片本身
# 只需要處理「選中/不可選」)。
# =========================================================

signal character_selected(character: Character)

const CARD_SIZE := Vector2(112, 112)

const _BG_COLOR := UiStyle.PARCHMENT_ROW_BG
const _BORDER_COLOR := UiStyle.PARCHMENT_ROW_BORDER
const _SELECTED_BORDER_COLOR := UiStyle.PARCHMENT_SELECTED_BORDER
const _UNAVAILABLE_ALPHA := 0.45

var character: Character
var available: bool = true
var unavailable_reason: String = ""

var selected: bool = false:
	set(value):
		selected = value
		_apply_style()


func _init(p_character: Character = null, p_available: bool = true, p_unavailable_reason: String = "") -> void:
	character = p_character
	available = p_available
	unavailable_reason = p_unavailable_reason


func _ready() -> void:
	custom_minimum_size = CARD_SIZE
	expand_icon = true
	if character != null:
		tooltip_text = character.full_name if available else unavailable_reason
		if not character.face_path.is_empty():
			icon = load(character.face_path) as Texture2D
	disabled = not available
	modulate.a = 1.0 if available else _UNAVAILABLE_ALPHA
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
	# disabled 不吃 modulate 以外的樣式就會退回引擎預設灰底,跟羊皮紙風格不搭——這裡沿用
	# 同一顆 style(不可選時外面已經另外套了 modulate.a 半透明,不需要再疊一次視覺區分)。
	add_theme_stylebox_override("disabled", style)
