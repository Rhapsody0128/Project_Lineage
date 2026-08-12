class_name BattlePartyRoster
extends VBoxContainer

# =========================================================
# 左右兩側的隊伍頭像列:一格正方形頭像(暫用 Warrier 正面圖佔位)、
# 角色名字、以及顯示「目前 HP/最大 HP」的血條。
# 只負責畫面表現,HP 數字全部來自 System/battle 的 BattleHero。
#
# 角色行動時(移動/攻擊/發呆/放技能)頭像會往戰場方向靠近一點,提示「輪到這個
# 角色動作」;放技能時額外把頭像框變色高亮,取代舊版「頭上飄技能名稱」的做法。
# =========================================================

const ENEMY_TINT := Color(1.0, 0.55, 0.55)
const SELF_TINT := Color(0.75, 0.85, 1.0)
const HP_BAR_FILL_SELF := Color(0.45, 0.85, 0.45)
const HP_BAR_BG := Color(0.1, 0.1, 0.12)
const PORTRAIT_SIZE := Vector2(50, 50)
const SLOT_SEPARATION := 8

# 行動提示:頭像往戰場方向位移的距離/時間(出去、停留、返回)
const ACTIVE_NUDGE_OFFSET := 16.0
const ACTIVE_OUT_TIME := 0.15
const ACTIVE_HOLD_TIME := 0.25
const ACTIVE_RETURN_TIME := 0.2

# 放技能時頭像框的高亮顏色
const SKILL_FRAME_COLOR := Color(1.0, 0.85, 0.2, 1.0)

class RosterSlot:
	var slot: VBoxContainer
	var portrait_frame: PanelContainer
	var frame_style: StyleBoxFlat
	var base_border_color: Color
	var bar: ProgressBar
	var hp_label: Label
	var max_count: int
	var active_tween: Tween
	var skill_tween: Tween

var _is_enemy := false
var _slots: Dictionary = {} # BattleHero -> RosterSlot


func clear_roster() -> void:
	for child in get_children():
		child.queue_free()
	_slots.clear()


## 依隊伍清單重新產生整列頭像;is_enemy 決定紅/藍配色,也決定頭像「靠近戰場」時
## 該往哪個方向位移(左側隊伍往右靠近,右側隊伍往左靠近)。
## fallback_portrait 在角色沒有頭像(face_path 空白或載入失敗)時當備用圖。
func populate(battle_heroes: Array[BattleHero], is_enemy: bool, fallback_portrait: Texture2D) -> void:
	clear_roster()
	_is_enemy = is_enemy
	add_theme_constant_override("separation", SLOT_SEPARATION)
	for battle_hero in battle_heroes:
		_spawn_slot(battle_hero, is_enemy, fallback_portrait)


func _spawn_slot(battle_hero: BattleHero, is_enemy: bool, fallback_portrait: Texture2D) -> void:
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
	portrait_frame.gui_input.connect(_on_portrait_gui_input.bind(battle_hero))

	var border_color := ENEMY_TINT if is_enemy else SELF_TINT
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.08, 0.08, 0.1, 0.6)
	frame_style.border_width_left = 2
	frame_style.border_width_top = 2
	frame_style.border_width_right = 2
	frame_style.border_width_bottom = 2
	frame_style.border_color = border_color
	frame_style.content_margin_left = 2.0
	frame_style.content_margin_top = 2.0
	frame_style.content_margin_right = 2.0
	frame_style.content_margin_bottom = 2.0
	portrait_frame.add_theme_stylebox_override("panel", frame_style)
	slot.add_child(portrait_frame)

	var portrait := TextureRect.new()
	portrait.texture = _load_hero_portrait(battle_hero, fallback_portrait)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.modulate = ENEMY_TINT if is_enemy else Color(1, 1, 1)
	portrait_frame.add_child(portrait)

	var name_label := Label.new()
	name_label.text = battle_hero.name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", border_color)
	slot.add_child(name_label)

	var max_count := battle_hero.hp_max

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 10)
	bar.max_value = max_count
	bar.value = battle_hero.hp
	bar.show_percentage = false

	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = ENEMY_TINT if is_enemy else HP_BAR_FILL_SELF
	bar.add_theme_stylebox_override("fill", bar_fill)

	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = HP_BAR_BG
	bar.add_theme_stylebox_override("background", bar_bg)
	slot.add_child(bar)

	var hp_label := Label.new()
	hp_label.text = "%d/%d" % [battle_hero.hp, max_count]
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.add_theme_font_size_override("font_size", 10)
	hp_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	slot.add_child(hp_label)

	var s := RosterSlot.new()
	s.slot = slot
	s.portrait_frame = portrait_frame
	s.frame_style = frame_style
	s.base_border_color = border_color
	s.bar = bar
	s.hp_label = hp_label
	s.max_count = max_count
	_slots[battle_hero] = s


## 更新某隊伍的血條與數字(remaining 為目前 HP)
func update_hp(battle_hero: BattleHero, remaining: int) -> void:
	var s: RosterSlot = _slots.get(battle_hero)
	if s == null:
		return

	s.bar.value = remaining
	s.hp_label.text = "%d/%d" % [remaining, s.max_count]


## 戰敗時血條歸零
func mark_defeated(battle_hero: BattleHero) -> void:
	update_hp(battle_hero, 0)


## 角色行動時(移動/攻擊/發呆/技能)頭像往戰場方向靠近一點再返回,提示「輪到這個
## 角色動作」。每格頭像各自有自己的位移動畫,彼此互不影響。
func pulse_active(battle_hero: BattleHero) -> void:
	var s: RosterSlot = _slots.get(battle_hero)
	if s == null:
		return

	if s.active_tween != null and s.active_tween.is_valid():
		s.active_tween.kill()
	s.slot.position.x = 0.0

	var offset_x := -ACTIVE_NUDGE_OFFSET if _is_enemy else ACTIVE_NUDGE_OFFSET
	s.active_tween = s.slot.create_tween()
	s.active_tween.tween_property(s.slot, "position:x", offset_x, ACTIVE_OUT_TIME)
	s.active_tween.tween_interval(ACTIVE_HOLD_TIME)
	s.active_tween.tween_property(s.slot, "position:x", 0.0, ACTIVE_RETURN_TIME)


## 放技能時:頭像照樣靠近戰場(pulse_active),另外把頭像框變色高亮一下,
## 取代舊版「頭上飄技能名稱」的畫面效果。
func pulse_skill(battle_hero: BattleHero) -> void:
	var s: RosterSlot = _slots.get(battle_hero)
	if s == null:
		return

	pulse_active(battle_hero)

	if s.skill_tween != null and s.skill_tween.is_valid():
		s.skill_tween.kill()
	s.frame_style.border_color = s.base_border_color

	s.skill_tween = s.portrait_frame.create_tween()
	s.skill_tween.tween_property(s.frame_style, "border_color", SKILL_FRAME_COLOR, ACTIVE_OUT_TIME)
	s.skill_tween.tween_interval(ACTIVE_HOLD_TIME)
	s.skill_tween.tween_property(s.frame_style, "border_color", s.base_border_color, ACTIVE_RETURN_TIME)


## 隊長的個人頭像(Images/Face 隨機圖);沒有頭像時退回 Warrier 佔位圖
func _load_hero_portrait(battle_hero: BattleHero, fallback_portrait: Texture2D) -> Texture2D:
	var face_path := battle_hero.hero.face_path
	if face_path.is_empty():
		return fallback_portrait
	var texture := load(face_path) as Texture2D
	return texture if texture != null else fallback_portrait


## 點擊頭像開啟共用角色面板(CharacterPanel 為 autoload 單例)
func _on_portrait_gui_input(input_event: InputEvent, battle_hero: BattleHero) -> void:
	if input_event is InputEventMouseButton and input_event.pressed and input_event.button_index == MOUSE_BUTTON_LEFT:
		CharacterPanel.open_for_hero(battle_hero.hero)
