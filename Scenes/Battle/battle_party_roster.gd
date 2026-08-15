class_name BattlePartyRoster
extends HBoxContainer

# =========================================================
# 左右兩側的隊伍頭像列:一格正方形頭像(暫用 Warrier 正面圖佔位)、
# 角色名字、以及顯示「目前 HP/最大 HP」的血條。
# 只負責畫面表現,HP 數字全部來自 System/battle 的 BattleHero。
#
# 小隊人數上限未來會開放到 12(見 CLAUDE.md),固定預留「6 列 x 2 欄」版面:第一欄
# 由上往下站滿 ROWS_PER_COLUMN(6)人,第 7 人才開始站第二欄(一樣由上往下)。這是
# 「先欄後列」的填法,GridContainer 的預設排法是「先列後欄」(依序左右排滿一列才
# 換下一列),兩者順序不同,所以這裡改用「HBoxContainer 包兩個 VBoxContainer 欄位」
# 自己控制哪個角色分到哪一欄(見 _column_a/_column_b/populate()),不直接用
# GridContainer。父節點包一層 CenterContainer(見 battle.tscn),人數不到上限時
# 整塊置中顯示,人數滿 12 時剛好填滿面板,不需要另外切兩套版面。
#
# 角色行動時(移動/攻擊/發呆/放技能)頭像會往戰場方向靠近一點,提示「輪到這個
# 角色動作」;放技能時額外把頭像框變色高亮,取代舊版「頭上飄技能名稱」的做法。
# =========================================================

## 單欄最多站幾人,滿了才開下一欄(見上面「先欄後列」註解)。
const ROWS_PER_COLUMN := 6

const ENEMY_TINT := Color(1.0, 0.55, 0.55)
const SELF_TINT := Color(0.75, 0.85, 1.0)
const HP_BAR_FILL_SELF := Color(0.45, 0.85, 0.45)
const HP_BAR_BG := Color(0.1, 0.1, 0.12)
## 頭像尺寸(從 50x50 縮小到 44x44):兩欄併排要塞進原本一欄的面板寬度
## (LeftPartyPanel/RightPartyPanel 112px,見 battle.tscn),縮小頭像才留得出兩欄
## + 欄距的空間,不用因此加寬面板、牽動戰場其餘版面。
const PORTRAIT_SIZE := Vector2(44, 44)
const SLOT_SEPARATION := 8

# 行動提示:頭像往戰場方向位移的距離/時間(出去、停留、返回)
const ACTIVE_NUDGE_OFFSET := 16.0
const ACTIVE_OUT_TIME := 0.15
const ACTIVE_HOLD_TIME := 0.25
const ACTIVE_RETURN_TIME := 0.2

# 放技能時頭像框的高亮顏色
const SKILL_FRAME_COLOR := Color(1.0, 0.85, 0.2, 1.0)

# 隊長頭像框:邊框顏色跟其他人一樣依武器分色(見 _spawn_slot()),只用加粗邊框寬度
# 區分隊長,實際的隊長標記(淡黃/深紅遮罩)改套在頭像本身,見 GameEnums.leader_tint()。
const LEADER_FRAME_BORDER_WIDTH := 3

# 技能名稱對話框(魔法漫畫風):偏紫的底色 + 金色邊框,跟頭像框高亮同色系
const SKILL_BUBBLE_BG := Color(0.16, 0.05, 0.28, 0.95)
const SKILL_BUBBLE_BORDER := Color(1.0, 0.85, 0.2, 1.0)
const SKILL_BUBBLE_TEXT_COLOR := Color(1.0, 0.95, 0.75)
const SKILL_BUBBLE_GAP := 6.0
const SKILL_BUBBLE_TAIL_SIZE := 12.0
const SKILL_BUBBLE_FADE_TIME := 0.15
const SKILL_BUBBLE_HOLD_TIME := 0.45

# 素質增益/減益箭頭:疊在頭像「正上方」左右兩個角標(左上=增益、右上=減益),
# 不再往頭像右側外溢——兩欄併排的頭像列(見上面 PORTRAIT_SIZE 註解)欄距只有
# SLOT_SEPARATION 這幾 px,外溢的箭頭會蓋到隔壁欄的頭像,所以改成疊在頭像本人
# 範圍內的角標,固定佔用同一塊區域,不會往下擠壓/推移同一份名單裡排在後面的角色
# (見 _spawn_slot() 的 portrait_row)。疊在頭像圖上要加外框(outline)才看得清楚。
# 同時中好幾種素質時,箭頭顏色依 GameEnums.potential_color() 每隔
# STATUS_ARROW_CYCLE_INTERVAL 秒輪流切換(見 _cycle_timer/_refresh_status_arrow()),
# 例如 +力量 +敏捷 就是紅→黃→紅…輪流跑,不會因為要同時顯示多種顏色而另外撐開版面。
const STATUS_ARROW_WIDTH := PORTRAIT_SIZE.x / 2.0
const STATUS_ARROW_HEIGHT := 16.0
const STATUS_ARROW_FONT_SIZE := 11
const STATUS_ARROW_OUTLINE_COLOR := Color(0.0, 0.0, 0.0, 0.9)
const STATUS_ARROW_OUTLINE_SIZE := 3
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
## 兩欄各自是獨立的 VBoxContainer(見上面「先欄後列」註解),populate() 依角色
## 索引分派到 _column_a(前 ROWS_PER_COLUMN 人)或 _column_b(第 7 人開始)。
var _column_a: VBoxContainer
var _column_b: VBoxContainer

# 所有角色的箭頭共用同一顆計時器輪流換色,不用每個角色各開一顆計時器。
var _cycle_index := 0
var _cycle_timer: Timer


func _ready() -> void:
	_cycle_timer = Timer.new()
	_cycle_timer.wait_time = STATUS_ARROW_CYCLE_INTERVAL
	_cycle_timer.autostart = true
	_cycle_timer.timeout.connect(_on_cycle_timer_timeout)
	add_child(_cycle_timer)

	add_theme_constant_override("separation", SLOT_SEPARATION)
	_column_a = VBoxContainer.new()
	_column_b = VBoxContainer.new()
	add_child(_column_a)
	add_child(_column_b)


func _on_cycle_timer_timeout() -> void:
	_cycle_index += 1
	for s in _slots.values():
		_refresh_status_arrow(s, true)
		_refresh_status_arrow(s, false)


func clear_roster() -> void:
	for child in _column_a.get_children():
		child.queue_free()
	for child in _column_b.get_children():
		child.queue_free()
	_slots.clear()


## 依隊伍清單重新產生整列頭像;is_enemy 決定紅/藍配色,也決定頭像「靠近戰場」時
## 該往哪個方向位移(左側隊伍往右靠近,右側隊伍往左靠近)。
## fallback_portrait 在角色沒有頭像(face_path 空白或載入失敗)時當備用圖。前
## ROWS_PER_COLUMN 人分到 _column_a、由上往下排,第 ROWS_PER_COLUMN+1 人開始才
## 輪到 _column_b(一樣由上往下),見上面「先欄後列」註解。
func populate(battle_heroes: Array[BattleHero], is_enemy: bool, fallback_portrait: Texture2D) -> void:
	clear_roster()
	_is_enemy = is_enemy
	_column_a.add_theme_constant_override("separation", SLOT_SEPARATION)
	_column_b.add_theme_constant_override("separation", SLOT_SEPARATION)
	for i in range(battle_heroes.size()):
		var column := _column_a if i < ROWS_PER_COLUMN else _column_b
		_spawn_slot(battle_heroes[i], is_enemy, fallback_portrait, column)


func _spawn_slot(battle_hero: BattleHero, is_enemy: bool, fallback_portrait: Texture2D, column: VBoxContainer) -> void:
	var slot := VBoxContainer.new()
	slot.add_theme_constant_override("separation", 2)
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	column.add_child(slot)

	# 頭像列一格不用 Container 排版(children 手動定位),這樣箭頭疊在頭像上顯示/隱藏時
	# 不會改變這一整格的大小,不會往下擠壓同排其他角色(見上面 STATUS_ARROW_WIDTH
	# 註解)。custom_minimum_size 就是頭像本身的大小,箭頭疊在同一塊範圍內,不會撐大
	# 這一格,也不會被算進置中寬度時多出額外空間。
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
	# 跟 BattleUnitVisual._setup_click_area() 同一個原因:暫停是直接切
	# SceneTree.paused,這顆頭像框是程式碼動態建立的,預設 process_mode 是
	# PAUSABLE,不補 ALWAYS 的話暫停後點頭像也會沒反應。
	portrait_frame.process_mode = Node.PROCESS_MODE_ALWAYS
	portrait_frame.gui_input.connect(_on_portrait_gui_input.bind(battle_hero))

	var is_leader := battle_hero.is_leader
	var border_color := GameEnums.weapon_border_color(battle_hero.hero.weapon)
	var border_width := LEADER_FRAME_BORDER_WIDTH if is_leader else 2
	var frame_style := UiStyle.bordered_panel(Color(0.08, 0.08, 0.1, 0.6), border_color, border_width, 0, 2.0, 2.0)
	portrait_frame.add_theme_stylebox_override("panel", frame_style)
	portrait_row.add_child(portrait_frame)

	var portrait := TextureRect.new()
	portrait.texture = _load_hero_portrait(battle_hero, fallback_portrait)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if is_leader:
		portrait.modulate = GameEnums.leader_tint(is_enemy)
	else:
		portrait.modulate = ENEMY_TINT if is_enemy else Color(1, 1, 1)
	portrait_frame.add_child(portrait)

	# 箭頭角標:疊在頭像「正上方」,固定切成左右各半格,左半格顯示增益箭頭、右半格
	# 顯示減益箭頭,沒有效果時該格的 Label 只是 visible=false,不影響區域本身的大小。
	# 疊在頭像圖上面(z-index 靠後加入的子節點蓋在先加入的 portrait_frame 之上)。
	var buff_arrow_label := _build_status_arrow_label("↑", Vector2(0, 0))
	var debuff_arrow_label := _build_status_arrow_label("↓", Vector2(STATUS_ARROW_WIDTH, 0))
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


## 箭頭角標固定切成左右各半格,疊在頭像正上方(見 _spawn_slot());arrow_pos 是
## 相對頭像左上角的位置,顏色由 _refresh_status_arrow() 依目前生效的素質即時套用,
## 預設不可見(沒有對應方向的效果時就藏起來)。疊在頭像圖上面,要加黑色外框字才
## 看得清楚(不管頭像底色深淺)。
func _build_status_arrow_label(arrow_text: String, arrow_pos: Vector2) -> Label:
	var label := Label.new()
	label.text = arrow_text
	label.position = arrow_pos
	label.size = Vector2(STATUS_ARROW_WIDTH, STATUS_ARROW_HEIGHT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", STATUS_ARROW_FONT_SIZE)
	label.add_theme_color_override("font_outline_color", STATUS_ARROW_OUTLINE_COLOR)
	label.add_theme_constant_override("outline_size", STATUS_ARROW_OUTLINE_SIZE)
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
	var color := GameEnums.potential_color(potential_type)
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
