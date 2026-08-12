class_name BattlePartyRoster
extends VBoxContainer

# =========================================================
# 左右兩側的隊伍頭像列:一格正方形頭像(暫用 Warrier 正面圖佔位)、
# 角色名字、以及顯示「當前兵力/最大兵力」的血條。
# 只負責畫面表現,兵力數字全部來自 System/battle 的 BattleParty。
# =========================================================

const ENEMY_TINT := Color(1.0, 0.55, 0.55)
const SELF_TINT := Color(0.75, 0.85, 1.0)
const HP_BAR_FILL_SELF := Color(0.45, 0.85, 0.45)
const HP_BAR_BG := Color(0.1, 0.1, 0.12)
const PORTRAIT_SIZE := Vector2(50, 50)
const SLOT_SEPARATION := 8

class RosterSlot:
	var bar: ProgressBar
	var hp_label: Label
	var max_count: int

var _slots: Dictionary = {} # BattleParty -> RosterSlot


func clear_roster() -> void:
	for child in get_children():
		child.queue_free()
	_slots.clear()


## 依隊伍清單重新產生整列頭像;is_enemy 決定紅/藍配色。
## fallback_portrait 在角色沒有頭像(face_path 空白或載入失敗)時當備用圖。
func populate(parties: Array[BattleParty], is_enemy: bool, fallback_portrait: Texture2D) -> void:
	clear_roster()
	add_theme_constant_override("separation", SLOT_SEPARATION)
	for battle_party in parties:
		_spawn_slot(battle_party, is_enemy, fallback_portrait)


func _spawn_slot(battle_party: BattleParty, is_enemy: bool, fallback_portrait: Texture2D) -> void:
	var slot := VBoxContainer.new()
	slot.add_theme_constant_override("separation", 2)
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(slot)

	# 頭像方框:每個角色一個正方形邊框,把頭像框住;點擊可開啟共用角色面板
	var portrait_frame := PanelContainer.new()
	portrait_frame.custom_minimum_size = PORTRAIT_SIZE
	portrait_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	portrait_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	portrait_frame.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	portrait_frame.gui_input.connect(_on_portrait_gui_input.bind(battle_party))

	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.08, 0.08, 0.1, 0.6)
	frame_style.border_width_left = 2
	frame_style.border_width_top = 2
	frame_style.border_width_right = 2
	frame_style.border_width_bottom = 2
	frame_style.border_color = ENEMY_TINT if is_enemy else SELF_TINT
	frame_style.content_margin_left = 2.0
	frame_style.content_margin_top = 2.0
	frame_style.content_margin_right = 2.0
	frame_style.content_margin_bottom = 2.0
	portrait_frame.add_theme_stylebox_override("panel", frame_style)
	slot.add_child(portrait_frame)

	var portrait := TextureRect.new()
	portrait.texture = _load_hero_portrait(battle_party, fallback_portrait)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.modulate = ENEMY_TINT if is_enemy else Color(1, 1, 1)
	portrait_frame.add_child(portrait)

	var name_label := Label.new()
	name_label.text = battle_party.name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", ENEMY_TINT if is_enemy else SELF_TINT)
	slot.add_child(name_label)

	var max_count := 0
	for soldier in battle_party.party.soldiers:
		max_count += soldier.soldiers_count_max

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 10)
	bar.max_value = max_count
	bar.value = battle_party.total_soldier_count
	bar.show_percentage = false

	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = ENEMY_TINT if is_enemy else HP_BAR_FILL_SELF
	bar.add_theme_stylebox_override("fill", bar_fill)

	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = HP_BAR_BG
	bar.add_theme_stylebox_override("background", bar_bg)
	slot.add_child(bar)

	var hp_label := Label.new()
	hp_label.text = "%d/%d" % [battle_party.total_soldier_count, max_count]
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.add_theme_font_size_override("font_size", 10)
	hp_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	slot.add_child(hp_label)

	var s := RosterSlot.new()
	s.bar = bar
	s.hp_label = hp_label
	s.max_count = max_count
	_slots[battle_party] = s


## 更新某隊伍的血條與數字(remaining 為當前兵力)
func update_hp(battle_party: BattleParty, remaining: int) -> void:
	var s: RosterSlot = _slots.get(battle_party)
	if s == null:
		return

	s.bar.value = remaining
	s.hp_label.text = "%d/%d" % [remaining, s.max_count]


## 全滅時血條歸零
func mark_defeated(battle_party: BattleParty) -> void:
	update_hp(battle_party, 0)


## 隊長的個人頭像(Images/Face 隨機圖);沒有頭像時退回 Warrier 佔位圖
func _load_hero_portrait(battle_party: BattleParty, fallback_portrait: Texture2D) -> Texture2D:
	var face_path := battle_party.party.hero.face_path
	if face_path.is_empty():
		return fallback_portrait
	var texture := load(face_path) as Texture2D
	return texture if texture != null else fallback_portrait


## 點擊頭像開啟共用角色面板(CharacterPanel 為 autoload 單例)
func _on_portrait_gui_input(input_event: InputEvent, battle_party: BattleParty) -> void:
	if input_event is InputEventMouseButton and input_event.pressed and input_event.button_index == MOUSE_BUTTON_LEFT:
		CharacterPanel.open_for_hero(battle_party.party.hero)
