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

# 隊長頭像框:固定金色邊框,取代原本紅/藍陣營色,一眼認出隊長
const LEADER_FRAME_COLOR := Color(1.0, 0.85, 0.2, 1.0)
const LEADER_FRAME_BORDER_WIDTH := 3

# 技能名稱對話框(魔法漫畫風):偏紫的底色 + 金色邊框,跟頭像框高亮同色系
const SKILL_BUBBLE_BG := Color(0.16, 0.05, 0.28, 0.95)
const SKILL_BUBBLE_BORDER := Color(1.0, 0.85, 0.2, 1.0)
const SKILL_BUBBLE_TEXT_COLOR := Color(1.0, 0.95, 0.75)
const SKILL_BUBBLE_GAP := 6.0
const SKILL_BUBBLE_TAIL_SIZE := 12.0
const SKILL_BUBBLE_FADE_TIME := 0.15
const SKILL_BUBBLE_HOLD_TIME := 0.45

# 素質增益/減益箭頭:固定佔頭像右側一塊「上箭頭/下箭頭各一格」的區域,不是往頭像
# 下方加一排——那樣行高會隨目前生效的 buff/debuff 數量變動,擠壓/推移同一份名單裡
# 排在後面的角色(見 _spawn_slot() 的 portrait_row)。同時中好幾種素質時,箭頭顏色
# 依 POTENTIAL_ARROW_COLORS 每隔 STATUS_ARROW_CYCLE_INTERVAL 秒輪流切換(見
# _cycle_timer/_refresh_status_arrow()),例如 +力量 +敏捷 就是紅→黃→紅…輪流跑,
# 不會因為要同時顯示多種顏色而另外撐開版面。
const POTENTIAL_ARROW_COLORS := {
	GameEnums.PotentialType.STRENGTH: Color(0.85, 0.2, 0.2), # 紅:力量
	GameEnums.PotentialType.DEXTERITY: Color(0.92, 0.92, 0.92), # 白:技巧(靈巧)
	GameEnums.PotentialType.AGILITY: Color(1.0, 0.85, 0.15), # 黃:敏捷
	GameEnums.PotentialType.VITALITY: Color(0.35, 0.85, 0.35), # 綠:體質
	GameEnums.PotentialType.INTELLIGENCE: Color(0.35, 0.55, 1.0), # 藍:智慧
	GameEnums.PotentialType.MENTALITY: Color(0.3, 0.9, 0.9), # 青:意志
}
const STATUS_ARROW_WIDTH := 20.0
const STATUS_ARROW_GAP := 4.0
const STATUS_ARROW_FONT_SIZE := 15
const STATUS_ARROW_CYCLE_INTERVAL := 1.0

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
	var skill_bubble: PanelContainer
	var buff_arrow_label: Label
	var debuff_arrow_label: Label
	var buff_types: Array[int] = []
	var debuff_types: Array[int] = []

var _is_enemy := false
var _slots: Dictionary = {} # BattleHero -> RosterSlot

# 所有角色的箭頭共用同一顆計時器輪流換色,不用每個角色各開一顆計時器。
var _cycle_index := 0
var _cycle_timer: Timer


func _ready() -> void:
	_cycle_timer = Timer.new()
	_cycle_timer.wait_time = STATUS_ARROW_CYCLE_INTERVAL
	_cycle_timer.autostart = true
	_cycle_timer.timeout.connect(_on_cycle_timer_timeout)
	add_child(_cycle_timer)


func _on_cycle_timer_timeout() -> void:
	_cycle_index += 1
	for s in _slots.values():
		_refresh_status_arrow(s, true)
		_refresh_status_arrow(s, false)


func clear_roster() -> void:
	for child in get_children():
		if child == _cycle_timer:
			continue
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

	# 頭像列一格不用 Container 排版(children 手動定位),這樣箭頭區顯示/隱藏箭頭時
	# 不會改變這一整格的大小,不會往下擠壓同排其他角色(見上面 POTENTIAL_ARROW_COLORS
	# 註解)。custom_minimum_size 刻意只算頭像本身的大小(跟箭頭無關)——置中計算只看
	# 這個大小,箭頭區是額外疊加在頭像右側的溢出內容(Control 預設不裁切子節點),不會
	# 被算進置中的寬度,頭像才能維持在原本沒有箭頭時一樣的置中位置,不會被箭頭往左推。
	var portrait_row := Control.new()
	portrait_row.custom_minimum_size = PORTRAIT_SIZE
	portrait_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	portrait_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(portrait_row)

	# 頭像方框:每個角色一個正方形邊框,把頭像框住;點擊可開啟共用角色面板
	var portrait_frame := PanelContainer.new()
	portrait_frame.position = Vector2.ZERO
	portrait_frame.size = PORTRAIT_SIZE
	portrait_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	portrait_frame.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	portrait_frame.gui_input.connect(_on_portrait_gui_input.bind(battle_hero))

	var is_leader := battle_hero.is_leader
	var border_color := LEADER_FRAME_COLOR if is_leader else (ENEMY_TINT if is_enemy else SELF_TINT)
	var border_width := LEADER_FRAME_BORDER_WIDTH if is_leader else 2
	var frame_style := UiStyle.bordered_panel(Color(0.08, 0.08, 0.1, 0.6), border_color, border_width, 0, 2.0, 2.0)
	portrait_frame.add_theme_stylebox_override("panel", frame_style)
	portrait_row.add_child(portrait_frame)

	var portrait := TextureRect.new()
	portrait.texture = _load_hero_portrait(battle_hero, fallback_portrait)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.modulate = ENEMY_TINT if is_enemy else Color(1, 1, 1)
	portrait_frame.add_child(portrait)

	# 箭頭區:貼著頭像「右側」,固定切成上下各半格,上半格顯示增益箭頭、下半格顯示
	# 減益箭頭,沒有效果時該格的 Label 只是 visible=false,不影響區域本身的大小。
	# x 座標要偏移過頭像寬度+間距,不然會疊在頭像框上面。
	var arrow_x := PORTRAIT_SIZE.x + STATUS_ARROW_GAP
	var buff_arrow_label := _build_status_arrow_label("↑", Vector2(arrow_x, 0))
	var debuff_arrow_label := _build_status_arrow_label("↓", Vector2(arrow_x, PORTRAIT_SIZE.y / 2.0))
	portrait_row.add_child(buff_arrow_label)
	portrait_row.add_child(debuff_arrow_label)

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
	s.buff_arrow_label = buff_arrow_label
	s.debuff_arrow_label = debuff_arrow_label
	_slots[battle_hero] = s


## 箭頭區固定切成上下各半格(見 _spawn_slot());arrow_pos 是相對箭頭區左上角的
## 位置,高度固定 PORTRAIT_SIZE.y/2,顏色由 _refresh_status_arrow() 依目前生效的
## 素質即時套用,預設不可見(沒有對應方向的效果時就藏起來)。
func _build_status_arrow_label(arrow_text: String, arrow_pos: Vector2) -> Label:
	var label := Label.new()
	label.text = arrow_text
	label.position = arrow_pos
	label.size = Vector2(STATUS_ARROW_WIDTH, PORTRAIT_SIZE.y / 2.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", STATUS_ARROW_FONT_SIZE)
	label.visible = false
	return label


## 更新某隊伍的血條與數字(remaining 為目前 HP)
func update_hp(battle_hero: BattleHero, remaining: int) -> void:
	var s: RosterSlot = _slots.get(battle_hero)
	if s == null:
		return

	s.bar.value = remaining
	s.hp_label.text = "%d/%d" % [remaining, s.max_count]


## 戰敗時血條歸零,順便把還沒到期的增益/減益箭頭一起清掉(人都倒了,不用再顯示)
func mark_defeated(battle_hero: BattleHero) -> void:
	update_hp(battle_hero, 0)
	var s: RosterSlot = _slots.get(battle_hero)
	if s == null:
		return
	s.buff_types.clear()
	s.debuff_types.clear()
	s.buff_arrow_label.visible = false
	s.debuff_arrow_label.visible = false


## 增益/減益生效:記錄這個方向(增益/減益)目前生效中的素質清單,箭頭本身固定佔用
## 頭像右側同一塊區域(見 _spawn_slot()),不會因為同時中好幾種素質就往外撐版面——
## 多種素質改用顏色輪流切換表示(見 _refresh_status_arrow())。同一個素質重複套用
## 只是刷新,不會在清單裡重複出現。
func add_status_arrows(battle_hero: BattleHero, potential_types: Array, is_buff: bool) -> void:
	var s: RosterSlot = _slots.get(battle_hero)
	if s == null:
		return

	var list := s.buff_types if is_buff else s.debuff_types
	for potential_type in potential_types:
		if not list.has(potential_type):
			list.append(potential_type)
	_refresh_status_arrow(s, is_buff)


## 增益/減益到期:從清單移除對應素質,清單清空時箭頭跟著藏起來。
func remove_status_arrows(battle_hero: BattleHero, potential_types: Array, is_buff: bool) -> void:
	var s: RosterSlot = _slots.get(battle_hero)
	if s == null:
		return

	var list := s.buff_types if is_buff else s.debuff_types
	for potential_type in potential_types:
		list.erase(potential_type)
	_refresh_status_arrow(s, is_buff)


## 依目前生效清單決定箭頭顯示/隱藏,清單有超過一種素質時,依 _cycle_index(共用計時器
## 每 STATUS_ARROW_CYCLE_INTERVAL 秒 +1,見 _on_cycle_timer_timeout())輪流顯示每一種
## 素質對應的顏色。
func _refresh_status_arrow(s: RosterSlot, is_buff: bool) -> void:
	var label := s.buff_arrow_label if is_buff else s.debuff_arrow_label
	var list := s.buff_types if is_buff else s.debuff_types

	if list.is_empty():
		label.visible = false
		return

	label.visible = true
	var potential_type: int = list[_cycle_index % list.size()]
	var color: Color = POTENTIAL_ARROW_COLORS.get(potential_type, Color.WHITE)
	label.add_theme_color_override("font_color", color)


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


## 放技能時:頭像照樣靠近戰場(pulse_active),頭像框變色高亮一下,
## 另外在頭像面向戰場那一側彈出一個漫畫風格的對話框,寫出招式名稱。
func pulse_skill(battle_hero: BattleHero, skill_name: String) -> void:
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

	_show_skill_bubble(s, skill_name)


## 在頭像旁(面向戰場的那一側)彈出一個邊框+底色的漫畫對話框,寫出招式名稱,
## 淡入停留一下後淡出釋放。對話框跟尖角尾巴掛在場景根節點下(而不是頭像列自己的
## VBoxContainer),因為 Container 會用自己的排版邏輯強制覆蓋子節點座標,沒辦法
## 手動定位在頭像外側。
func _show_skill_bubble(s: RosterSlot, skill_name: String) -> void:
	if s.skill_bubble != null and is_instance_valid(s.skill_bubble):
		s.skill_bubble.queue_free()

	var bubble := PanelContainer.new()
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.modulate.a = 0.0

	# 場上角色固定 z_index=-1、地板固定 -2(見 BattleUnitVisual.CHARACTER_Z_INDEX),
	# 對話框只要維持非負值就一定蓋在兩者之上,不會被戰場上的角色圖擋住。
	bubble.z_index = 2

	var style := StyleBoxFlat.new()
	style.bg_color = SKILL_BUBBLE_BG
	style.border_color = SKILL_BUBBLE_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(6)
	bubble.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = skill_name
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_color_override("font_color", SKILL_BUBBLE_TEXT_COLOR)
	bubble.add_child(label)

	var tail := Panel.new()
	tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tail.modulate.a = 0.0
	tail.size = Vector2(SKILL_BUBBLE_TAIL_SIZE, SKILL_BUBBLE_TAIL_SIZE)
	tail.pivot_offset = tail.size * 2
	tail.rotation_degrees = 45

	var tail_style := StyleBoxFlat.new()
	tail_style.bg_color = SKILL_BUBBLE_BG
	tail_style.border_color = SKILL_BUBBLE_BORDER
	tail_style.set_border_width_all(2)
	tail.add_theme_stylebox_override("panel", tail_style)

	var overlay: Node = get_tree().current_scene if get_tree() != null else null
	if overlay == null:
		overlay = self
	overlay.add_child(bubble)
	overlay.add_child(tail)
	s.skill_bubble = bubble

	_animate_skill_bubble(s, bubble, tail)


## 等一影格讓對話框依內容算出實際尺寸,再依頭像位置(面向戰場那一側)定位對話框
## 與尖角尾巴,接著淡入 → 停留 → 淡出 → 釋放。
func _animate_skill_bubble(s: RosterSlot, bubble: PanelContainer, tail: Panel) -> void:
	await get_tree().process_frame

	if not is_instance_valid(bubble) or not is_instance_valid(s.portrait_frame):
		if is_instance_valid(bubble):
			bubble.queue_free()
		if is_instance_valid(tail):
			tail.queue_free()
		return

	bubble.size = bubble.get_combined_minimum_size()

	var anchor := s.portrait_frame.global_position
	var anchor_size := s.portrait_frame.size

	var bubble_pos: Vector2
	var tail_pos: Vector2
	if _is_enemy:
		bubble_pos = anchor + Vector2(-SKILL_BUBBLE_GAP - bubble.size.x, anchor_size.y * 0.5 - bubble.size.y * 0.5)
		tail_pos = anchor + Vector2(-SKILL_BUBBLE_GAP * 0.5 - SKILL_BUBBLE_TAIL_SIZE * 0.5, anchor_size.y * 0.5 - SKILL_BUBBLE_TAIL_SIZE * 0.5)
	else:
		bubble_pos = anchor + Vector2(anchor_size.x + SKILL_BUBBLE_GAP, anchor_size.y * 0.5 - bubble.size.y * 0.5)
		tail_pos = anchor + Vector2(anchor_size.x + SKILL_BUBBLE_GAP * 0.5 - SKILL_BUBBLE_TAIL_SIZE * 0.5, anchor_size.y * 0.5 - SKILL_BUBBLE_TAIL_SIZE * 0.5)

	bubble.global_position = bubble_pos
	tail.global_position = tail_pos

	var tw := bubble.create_tween()
	tw.tween_property(bubble, "modulate:a", 1.0, SKILL_BUBBLE_FADE_TIME)
	tw.parallel().tween_property(tail, "modulate:a", 1.0, SKILL_BUBBLE_FADE_TIME)
	tw.tween_interval(SKILL_BUBBLE_HOLD_TIME)
	tw.tween_property(bubble, "modulate:a", 0.0, SKILL_BUBBLE_FADE_TIME)
	tw.parallel().tween_property(tail, "modulate:a", 0.0, SKILL_BUBBLE_FADE_TIME)
	tw.tween_callback(bubble.queue_free)
	tw.tween_callback(tail.queue_free)


## 隊長的個人頭像(Images/Face 隨機圖);沒有頭像時退回 Warrier 佔位圖
func _load_hero_portrait(battle_hero: BattleHero, fallback_portrait: Texture2D) -> Texture2D:
	var face_path := battle_hero.hero.face_path
	if face_path.is_empty():
		return fallback_portrait
	var texture := load(face_path) as Texture2D
	return texture if texture != null else fallback_portrait


## 點擊頭像開啟共用角色面板(CharacterPanel 為 autoload 單例)。多帶 battle_hero,
## 讓面板的雷達圖能顯示套用完戰場加成的即時數值,見 CharacterPanel.open_for_hero()。
func _on_portrait_gui_input(input_event: InputEvent, battle_hero: BattleHero) -> void:
	if input_event is InputEventMouseButton and input_event.pressed and input_event.button_index == MOUSE_BUTTON_LEFT:
		CharacterPanel.open_for_hero(battle_hero.hero, battle_hero)
