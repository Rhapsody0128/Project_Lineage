class_name BattleUnitVisual
extends Node2D

# =========================================================
# 場上單一角色的畫面呈現(動畫、位置補間)。
# 頭上不常駐顯示名字/HP,也不顯示技能名稱橫幅——放技能時改成左右頭像列
# (BattlePartyRoster)的頭像框高亮+靠近戰場提示,名字與 HP 也是由頭像列常駐顯示。
# 只負責畫面表現,不含任何戰鬥判定邏輯 —— 判定全部來自
# System/battle 的 BattleCharacter,棋盤座標/像素座標換算則由
# battle.gd(棋盤)負責,本檔案只依照傳進來的結果播放。
# =========================================================

const ENEMY_TINT := Color(1.0, 0.55, 0.55)
const SPRITE_SCALE := Vector2(1.3, 1.3)

# 戰敗淡出:先停頓一下讓玩家看清楚倒下的瞬間,再緩緩淡到全透明消失
const DEATH_FADE_DELAY := 0.4
const DEATH_FADE_TIME := 1.0

# Warrier 的動畫素材(sprite_frames)全部設為循環播放(loop),
# 代表 AnimatedSprite2D 的 animation_finished 訊號永遠不會觸發,
# 因此攻擊/技能動畫改用「動畫長度計時」等待,不依賴該訊號。
const ATTACK_ANIM_FALLBACK_TIME := 0.4

# 傷害數字浮字顯示時間
const DAMAGE_NUMBER_RISE_TIME := 0.5

# 連續命中(二/三連擊、AoE 命中同一格附近角色)短時間內連續跳出好幾個飄字時,
# 依連續次數逐步延遲後面幾個的出現時機,讓玩家看得出這是「好幾下」而不是疊在一起
# 糊成一團的一個數字——超過 FLOATING_NUMBER_STAGGER_RESET_MS 沒有新的飄字才視為
# 新的一輪連擊,streak 歸零重新算。
const FLOATING_NUMBER_STAGGER_STEP := 0.14
const FLOATING_NUMBER_STAGGER_RESET_MS := 250
var _floating_number_streak := 0
var _last_floating_number_ms := -1000000

# 傷害數字:一般傷害用白字,暴擊用紅字放更大顯示,一眼就能看出這下是不是暴擊
const DAMAGE_NUMBER_FONT_SIZE := 28
const CRIT_DAMAGE_NUMBER_FONT_SIZE := 40
const DAMAGE_NUMBER_COLOR := Color(1.0, 1.0, 1.0)
const CRIT_DAMAGE_NUMBER_COLOR := Color(1.0, 0.15, 0.15)

# 受擊反應:閃白顏色與左右震動幅度(像素)
const HIT_FLASH_COLOR := Color(3.0, 3.0, 3.0, 1.0)
const HIT_SHAKE_OFFSET := 6.0

# 閃避反應:側身晃一下的位移(像素),不閃白、不震動,跟受擊反應明確區分開來
const DODGE_STEP_OFFSET := Vector2(26.0, -16.0)

# 完美迴避反應:左右來回移動(像素),跟一般閃避的單次側身晃動明確區分開來,
# 讓玩家一眼看出這次是被動技能發動而不是單純的 AGI/DEX 判定閃開
const PERFECT_DODGE_STEP_OFFSET := 34.0
const PERFECT_DODGE_STEP_TIME := 0.09

# 治療飄字:綠色,樣式比照傷害數字但方向相反(不需要暴擊分級)
const HEAL_NUMBER_COLOR := Color(0.4, 1.0, 0.5)
const HEAL_NUMBER_FONT_SIZE := 28

# 守護位移:守護者飛身到受擊者面前(面向攻擊方)頂替承受攻擊,再退回原位。
# STAND_OFFSET_PIXELS 是「站在受擊者面前」時,沿著「受擊者→攻擊方」方向再往前
# 多少像素(擋在中間、但不會整個疊到受擊者身上)。這裡只動 BattleUnitVisual 自己的
# position(畫面補間),不影響 System 層的棋盤格座標,下一次移動判定仍以原格為準。
const GUARD_DASH_TIME := 0.18
const GUARD_STAND_OFFSET_PIXELS := 30.0

# 施放技能反應:角色腳底炸出一道光,而不是角色本身閃白——
# 快速放大淡入 → 停格 1 秒(讓玩家看清楚是誰放了技能)→ 快速淡出消失。
const SKILL_LIGHT_TEXTURE := preload("res://Images/Effect/skill_light.webp")
const SKILL_LIGHT_SCALE := 0.6
const SKILL_LIGHT_POP_START_SCALE := 0.2
const SKILL_LIGHT_POP_TIME := 0.12
const SKILL_LIGHT_HOLD_TIME := 1.0
const SKILL_LIGHT_FADE_OUT_TIME := 0.2

# 素質增益/減益生效瞬間:原地依序切換四個方向的待機動畫,演出「轉一圈」提示被強化
# 或被詛咒,buff/debuff 共用同一段演出,顏色/方向靠頭像列的箭頭圖示分辨(見
# BattlePartyRoster.add_status_arrows)。
const STAT_EFFECT_SPIN_STEP_TIME := 0.12
const STAT_EFFECT_SPIN_SEQUENCE: Array[Vector2i] = [
	Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 0),
]

# 測試階段除錯用:角色右下角常駐顯示目前所持武器文字,方便肉眼核對武器與距離/傷害
# 行為是否對得上;正式美術/UI 定案後把這個常數改成 false 即可整段關閉,不用刪程式碼。
const SHOW_DEBUG_WEAPON_LABEL := true
const WEAPON_LABEL_POSITION := Vector2(20, 12)
const WEAPON_LABEL_FONT_SIZE := 12

# 點擊戰場上角色本人(暫代 Warrier 圖)開啟角色面板用的判定範圍:貼合 sprite 的
# 32x46 原始素材套用 SPRITE_SCALE 後的大小,置中對齊 sprite.position(見 setup())。
const CLICK_AREA_SIZE := Vector2(42, 60)
const CLICK_AREA_OFFSET := Vector2(0, -8)

# 隊長標記:小人物右上角疊一面小旗子圖示(見 GameEnums.LEADER_FLAG_ICON_PATH)——
# PartyEdit/CharacterPanel 的 battle_cost 縮圖(見 BattleCostView)也用同一張圖,
# 標記邏輯要一致,所以路徑集中放在 GameEnums 不在這裡各自定義一份。圖示中心點對齊
# 點擊判定範圍(CLICK_AREA_SIZE/OFFSET)的右上角,呈現「掛在角落」的效果。
const LEADER_ICON_TARGET_WIDTH := 22.0
const LEADER_ICON_POSITION := Vector2(CLICK_AREA_OFFSET.x + CLICK_AREA_SIZE.x / 2.0, CLICK_AREA_OFFSET.y - CLICK_AREA_SIZE.y / 2.0)

# 特殊狀態文字(恐懼/封印/嘲諷/降治療/全隊限時破防&必定暴擊):疊在角色右上角,比隊長
# 旗子再往右上一點,避免兩者疊在一起看不清楚——跟 BattlePartyRoster 的頭像左上角文字
# 是同一份資料來源(GameEnums.mechanic_status_label()),只是位置換成角色本人的右上角。
const STATUS_LABEL_POSITION := Vector2(CLICK_AREA_OFFSET.x + CLICK_AREA_SIZE.x * 0.5, CLICK_AREA_OFFSET.y - CLICK_AREA_SIZE.y - 14.0)
const STATUS_LABEL_SIZE := Vector2(70, 14)
const STATUS_LABEL_FONT_SIZE := 12
const STATUS_LABEL_COLOR := Color(1.0, 0.75, 0.25, 1.0)
const STATUS_LABEL_OUTLINE_COLOR := Color(0.0, 0.0, 0.0, 0.9)
const STATUS_LABEL_OUTLINE_SIZE := 3

# 圖層順序:地板(BattleBoard)固定 z_index=-2 墊底,角色固定疊在地板上方一層,
# 頭像列彈出的招式喊話框等 UI 疊層維持預設(0)或正值,永遠蓋在角色之上——不再依
# grid_pos.y 逐格排序景深(格子間距已經讓同排角色的圖不會互相重疊,這個細節犧牲掉
# 換來一個簡單、不會再被 UI 反蓋住的固定圖層規則)。
const CHARACTER_Z_INDEX := -1

var battle_character: BattleCharacter
var is_enemy: bool
var grid_pos: Vector2i

var sprite: AnimatedSprite2D

var _status_label: Label
var _status_mechanic_types: Array[int] = []


## 建立角色顯示(動畫),pixel_pos 為棋盤換算好的初始位置
func setup(p_battle_character: BattleCharacter, p_is_enemy: bool, character_scene: PackedScene, pixel_pos: Vector2) -> void:
	battle_character = p_battle_character
	is_enemy = p_is_enemy
	grid_pos = battle_character.grid_pos
	position = pixel_pos
	z_index = CHARACTER_Z_INDEX

	var character := character_scene.instantiate()
	add_child(character)
	sprite = character as AnimatedSprite2D

	if sprite == null:
		printerr("角色 Scene 不是 AnimatedSprite2D")
	else:
		sprite.scale = SPRITE_SCALE
		sprite.position = Vector2(0, -8)

		# 我方(左側)面朝右與敵人對戰,敵方(右側)面朝左。
		if is_enemy:
			sprite.play("idle_Left")
			sprite.modulate = ENEMY_TINT
		else:
			sprite.play("idle_Right")

	if battle_character.is_leader:
		_setup_leader_icon()

	_setup_status_label()

	if SHOW_DEBUG_WEAPON_LABEL:
		_setup_weapon_label()

	_setup_click_area()


## 隊長標記:右上角疊一面小旗子(見上方 LEADER_ICON_* 常數說明)。
func _setup_leader_icon() -> void:
	var icon := Sprite2D.new()
	icon.texture = load(GameEnums.LEADER_FLAG_ICON_PATH)
	icon.centered = true
	icon.position = LEADER_ICON_POSITION
	icon.z_as_relative = true
	icon.z_index = 1
	var tex_width := icon.texture.get_width()
	if tex_width > 0:
		icon.scale = Vector2.ONE * (LEADER_ICON_TARGET_WIDTH / tex_width)
	add_child(icon)


## 特殊狀態文字:右上角疊一個文字 Label(見上方 STATUS_LABEL_* 常數說明),預設不可見,
## 內容/顯示由 add_status_mechanic()/remove_status_mechanic() 依戰報事件即時更新。
func _setup_status_label() -> void:
	_status_label = Label.new()
	_status_label.position = STATUS_LABEL_POSITION
	_status_label.size = STATUS_LABEL_SIZE
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_label.z_as_relative = true
	_status_label.z_index = 1
	_status_label.add_theme_font_size_override("font_size", STATUS_LABEL_FONT_SIZE)
	_status_label.add_theme_color_override("font_color", STATUS_LABEL_COLOR)
	_status_label.add_theme_color_override("font_outline_color", STATUS_LABEL_OUTLINE_COLOR)
	_status_label.add_theme_constant_override("outline_size", STATUS_LABEL_OUTLINE_SIZE)
	_status_label.visible = false
	add_child(_status_label)


## 特殊狀態機制生效/到期(恐懼/封印/嘲諷/降治療/全隊限時破防&必定暴擊):跟
## BattlePartyRoster.add_status_mechanic()/remove_status_mechanic() 同一份資料來源
## (GameEnums.mechanic_status_label()),只是顯示位置換成角色本人右上角,見 battle.gd
## 的 StatusMechanicEvent 處理。
func add_status_mechanic(mechanic: int) -> void:
	if not _status_mechanic_types.has(mechanic):
		_status_mechanic_types.append(mechanic)
	_refresh_status_label()


func remove_status_mechanic(mechanic: int) -> void:
	_status_mechanic_types.erase(mechanic)
	_refresh_status_label()


func _refresh_status_label() -> void:
	if _status_label == null:
		return
	if _status_mechanic_types.is_empty():
		_status_label.visible = false
		return

	var labels: Array[String] = []
	for mechanic in _status_mechanic_types:
		labels.append(GameEnums.mechanic_status_label(mechanic))
	_status_label.text = "/".join(labels)
	_status_label.visible = true


## 場上角色本人(不是頭像列的頭像,見 BattlePartyRoster._on_portrait_gui_input)也能
## 點擊開啟共用角色面板。角色是 Node2D 而不是 Control,不走 gui_input 那一套,改用
## Area2D + 物理揀選(battle.gd._ready() 已開啟 Viewport.physics_object_picking)。
func _setup_click_area() -> void:
	var click_area := Area2D.new()
	click_area.input_pickable = true
	# 暫停鍵是直接切 SceneTree.paused(見 battle.gd 的 _on_pause_pressed()),預設
	# process_mode 是 PAUSABLE,暫停後這顆 Area2D 就收不到物理揀選事件,點角色本人
	# 會完全沒反應——PauseButton/SkipButton 等 UI 按鈕在 battle.tscn 都已經明講
	# process_mode=ALWAYS 才能在暫停中繼續運作,這裡是程式碼動態建立的節點,一樣要
	# 補上,玩家才能在暫停時點角色看面板。
	click_area.process_mode = Node.PROCESS_MODE_ALWAYS

	var shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = CLICK_AREA_SIZE
	shape.shape = rect_shape
	shape.position = CLICK_AREA_OFFSET
	click_area.add_child(shape)

	click_area.input_event.connect(_on_click_area_input_event)
	add_child(click_area)


func _on_click_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		CharacterPanel.open_for_character(battle_character.character, battle_character)


## 測試階段除錯用,見 SHOW_DEBUG_WEAPON_LABEL 常數說明
func _setup_weapon_label() -> void:
	var label := Label.new()
	label.text = GameEnums.weapon_label(battle_character.character.weapon)
	label.add_theme_font_size_override("font_size", WEAPON_LABEL_FONT_SIZE)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.position = WEAPON_LABEL_POSITION
	add_child(label)



# =========================================================
# 方向與動畫
# =========================================================
func _dir_name(dir: Vector2i) -> String:
	if dir.x > 0:
		return "Right"
	elif dir.x < 0:
		return "Left"
	elif dir.y > 0:
		return "Down"
	elif dir.y < 0:
		return "Top"
	return "Down"


## 播放動畫並回傳實際播放的動畫名稱(供計算等待時間用)
func _play_dir_anim(dir: Vector2i, prefix: String) -> String:
	var anim := "%s_%s" % [prefix, _dir_name(dir)]

	if sprite == null:
		return anim

	if sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)
	else:
		printerr("找不到動畫：", anim, " / 角色：", battle_character.name)

	return anim


func play_idle(dir: Vector2i) -> void:
	if sprite == null:
		return

	var anim := "idle_%s" % _dir_name(dir)

	if sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)


## 朝目標格子的方向播放待機動畫(攻擊/技能結束後轉回面朝對方)
func idle_towards(target_grid: Vector2i) -> void:
	play_idle(target_grid - grid_pos)


## 沿路徑連續補間移動,path_grid/path_pixel 一一對應;
## 方向不變就不重播走路動畫,避免每格都重播造成的頓挫感。
func move_along(path_grid: Array, path_pixel: Array, move_time: float) -> void:
	var last_dir := Vector2i.ZERO

	for i in range(path_grid.size()):
		var to_grid: Vector2i = path_grid[i]
		var to_pixel: Vector2 = path_pixel[i]
		var dir: Vector2i = to_grid - grid_pos

		if dir != last_dir:
			_play_dir_anim(dir, "walk")
			last_dir = dir

		grid_pos = to_grid

		var tw := create_tween()
		tw.tween_property(self, "position", to_pixel, move_time)
		await tw.finished

	play_idle(last_dir)


## 朝目標格子播放攻擊動畫,回傳動畫名稱供 wait_for_animation 使用
func play_attack_towards(target_grid: Vector2i) -> String:
	return _play_dir_anim(target_grid - grid_pos, "attack")


## 動畫素材為循環播放,animation_finished 不會觸發,改用長度計時等待
func wait_for_animation(anim_name: String) -> void:
	var duration := ATTACK_ANIM_FALLBACK_TIME

	if sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim_name):
		var frame_count := sprite.sprite_frames.get_frame_count(anim_name)
		var speed := sprite.sprite_frames.get_animation_speed(anim_name)
		if speed > 0.0 and frame_count > 0:
			duration = frame_count / speed

	if not is_inside_tree():
		return
	# process_always=false:跟著 SceneTree.paused 一起暫停,配合戰報的暫停按鈕。
	await get_tree().create_timer(duration, false).timeout


## 受到傷害時在頭上跳出傷害數字,往上飄並淡出。is_critical 決定用一般(白字)還是
## 暴擊(紅字,字級更大)樣式,讓玩家不用看戰報文字就能一眼分辨這下有沒有暴擊。
func show_damage_number(amount: int, is_critical: bool = false) -> void:
	var font_size := CRIT_DAMAGE_NUMBER_FONT_SIZE if is_critical else DAMAGE_NUMBER_FONT_SIZE
	var color := CRIT_DAMAGE_NUMBER_COLOR if is_critical else DAMAGE_NUMBER_COLOR
	_show_floating_number("-%d" % amount, color, font_size, _next_floating_number_stagger())


## 恢復 HP 時在頭上跳出綠色治療數字,樣式比照 show_damage_number() 但方向相反
## (正數、綠色),讓玩家一眼分辨是傷害還是治療。
func show_heal_number(amount: int) -> void:
	_show_floating_number("+%d" % amount, HEAL_NUMBER_COLOR, HEAL_NUMBER_FONT_SIZE, _next_floating_number_stagger())


## 依短時間內連續跳出飄字的次數算出這一次要延遲多久才出現(見上方 FLOATING_NUMBER_
## STAGGER_* 常數),超過重置窗口沒有新飄字就視為新的一輪、從頭數起。
func _next_floating_number_stagger() -> float:
	var now := Time.get_ticks_msec()
	if now - _last_floating_number_ms <= FLOATING_NUMBER_STAGGER_RESET_MS:
		_floating_number_streak += 1
	else:
		_floating_number_streak = 0
	_last_floating_number_ms = now
	return _floating_number_streak * FLOATING_NUMBER_STAGGER_STEP


## show_damage_number()/show_heal_number() 共用的飄字實作:往上飄一小段、停頓、
## 淡出釋放,兩者只差文字內容/顏色/字級;stagger_delay > 0 時先等這麼久才開始淡入,
## 讓連續命中的好幾個數字錯開出現時機,不會疊在同一個位置糊成一團。
func _show_floating_number(text: String, color: Color, font_size: int, stagger_delay: float = 0.0) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 5)
	label.position = Vector2(-60, -110)
	label.size = Vector2(120, 40)
	label.modulate = Color(1, 1, 1, 0)
	# 飄字往上飄的過程可能飄進旁邊(尤其站前排的)角色的畫面範圍——所有角色都固定
	# 同一個 z_index(見 CHARACTER_Z_INDEX),同層級時只能靠子節點加入順序決定誰畫在
	# 上面,飄字所屬的角色不一定比旁邊角色晚加入,不能只靠這個順序保證蓋得住。這裡
	# 明確給飄字 +1 的相對 z(疊上父節點的 -1 變成 0),嚴格高於所有角色,才穩定蓋在
	# 最上面。
	label.z_as_relative = true
	label.z_index = 1
	add_child(label)

	var tw := label.create_tween()
	if stagger_delay > 0.0:
		tw.tween_interval(stagger_delay)
	tw.tween_property(label, "modulate:a", 1.0, 0.05)
	tw.parallel().tween_property(label, "position:y", label.position.y - 24.0, DAMAGE_NUMBER_RISE_TIME)
	tw.tween_interval(0.15)
	tw.tween_property(label, "modulate:a", 0.0, 0.25)
	tw.tween_callback(label.queue_free)


## 被攻擊但閃避成功時的反應:側身晃一下,不閃白、不震動,跟 play_hit_reaction() 區分,
## 讓玩家一眼看出這一擊沒有命中。
func play_dodge_reaction() -> void:
	if sprite == null:
		return

	var base_pos := sprite.position

	var tw := create_tween()
	tw.tween_property(sprite, "position", base_pos + DODGE_STEP_OFFSET, 0.1)
	tw.tween_property(sprite, "position", base_pos, 0.16)


## 完美迴避(PERFECT_DODGE 武器被動)觸發時的反應:左右來回移動,跟 play_dodge_reaction()
## 單純側身晃一下明確做出區分——這是被動技能發動而不是普通的判定閃避,見
## DodgeEvent.skill_name/battle.gd 的分流。
func play_perfect_dodge_reaction() -> void:
	if sprite == null:
		return

	var base_pos := sprite.position
	var side := -1.0 if is_enemy else 1.0

	var tw := create_tween()
	tw.tween_property(sprite, "position", base_pos + Vector2(-PERFECT_DODGE_STEP_OFFSET * side, 0.0), PERFECT_DODGE_STEP_TIME)
	tw.tween_property(sprite, "position", base_pos + Vector2(PERFECT_DODGE_STEP_OFFSET * side, 0.0), PERFECT_DODGE_STEP_TIME)
	tw.tween_property(sprite, "position", base_pos, PERFECT_DODGE_STEP_TIME)


## 守護觸發:守護者從原地飛身位移到「受擊者面前、面向攻擊方」的位置頂替承受攻擊。
## target_pos/attacker_pos 是受擊者、攻擊方目前的 Node2D.position(跟 self 同一個
## UnitsLayer 底下,座標系一致,不需要另外轉換)。只動畫面位置,不動棋盤格,
## 所以要記住起點,等 play_guard_dash_out() 呼叫時才歸位。
var _guard_home_position: Vector2
var _guard_home_set := false

func play_guard_dash_in(target_pos: Vector2, attacker_pos: Vector2) -> void:
	_guard_home_position = position
	_guard_home_set = true

	var dir_to_attacker := attacker_pos - target_pos
	if dir_to_attacker.length() < 0.001:
		dir_to_attacker = Vector2(1.0 if not is_enemy else -1.0, 0.0)
	dir_to_attacker = dir_to_attacker.normalized()

	var stand_pos := target_pos + dir_to_attacker * GUARD_STAND_OFFSET_PIXELS
	var face_dir := Vector2i(signi(dir_to_attacker.x), signi(dir_to_attacker.y))

	_play_dir_anim(face_dir, "walk")
	var tw := create_tween()
	tw.tween_property(self, "position", stand_pos, GUARD_DASH_TIME)
	await tw.finished
	play_idle(face_dir)


## 守護結束:退回飛身前的原始位置,轉回面朝戰場的預設方向。
func play_guard_dash_out() -> void:
	if not _guard_home_set:
		return
	var home := _guard_home_position
	_guard_home_set = false

	var tw := create_tween()
	tw.tween_property(self, "position", home, GUARD_DASH_TIME)
	await tw.finished
	play_idle(Vector2i(1, 0) if not is_enemy else Vector2i(-1, 0))


## 受到傷害時的受擊反應:快速閃白 + 左右震動,提示這次攻擊有造成傷害。
## 只動 sprite 的區域座標(不動 self.position),避免跟移動補間搶同一個屬性。
func play_hit_reaction() -> void:
	if sprite == null:
		return

	var base_modulate := sprite.modulate
	var base_pos := sprite.position

	var tw := create_tween()
	tw.tween_property(sprite, "modulate", HIT_FLASH_COLOR, 0.04)
	tw.parallel().tween_property(sprite, "position", base_pos + Vector2(HIT_SHAKE_OFFSET, 0), 0.04)
	tw.tween_property(sprite, "position", base_pos - Vector2(HIT_SHAKE_OFFSET, 0), 0.04)
	tw.parallel().tween_property(sprite, "modulate", base_modulate, 0.08)
	tw.tween_property(sprite, "position", base_pos, 0.04)


## 施放技能瞬間在角色腳底炸出一道光,提示這是技能而不是普通攻擊,跟頭像列的對話框
## 同時播放。光效貼在角色腳下(本節點原點,貼圖底邊對齊),疊在角色前面,
## 快速放大淡入後停格 1 秒,再淡出釋放。
func play_skill_light() -> void:
	var effect := Sprite2D.new()
	effect.texture = SKILL_LIGHT_TEXTURE
	effect.centered = true

	# 角色腳底 = BattleUnitVisual 的原點
	effect.position = Vector2(0, 0)

	effect.z_index = -1
	effect.modulate.a = 0.0
	effect.scale = Vector2.ONE * SKILL_LIGHT_POP_START_SCALE
	add_child(effect)

	var tw := create_tween()
	tw.tween_property(effect, "modulate:a", 1.0, SKILL_LIGHT_POP_TIME)
	tw.parallel().tween_property(
		effect,
		"scale",
		Vector2.ONE * SKILL_LIGHT_SCALE,
		SKILL_LIGHT_POP_TIME
	)
	tw.tween_interval(SKILL_LIGHT_HOLD_TIME)
	tw.tween_property(effect, "modulate:a", 0.0, SKILL_LIGHT_FADE_OUT_TIME)
	tw.tween_callback(effect.queue_free)


## 素質增益/減益生效瞬間播放:依序切換四個方向的待機動畫演出「原地轉一圈」,
## 轉完後轉回面朝戰場的預設方向(我方朝右、敵方朝左),提示這下是被強化還是被詛咒。
func play_stat_effect_spin() -> void:
	if sprite == null:
		return

	for dir in STAT_EFFECT_SPIN_SEQUENCE:
		_play_dir_anim(dir, "idle")
		await get_tree().create_timer(STAT_EFFECT_SPIN_STEP_TIME, false).timeout

	play_idle(Vector2i(1, 0) if not is_enemy else Vector2i(-1, 0))


func apply_defeated() -> void:
	var tw := create_tween()
	tw.tween_interval(DEATH_FADE_DELAY)
	tw.tween_property(self, "modulate:a", 0.0, DEATH_FADE_TIME)
	tw.tween_callback(func() -> void: visible = false)
