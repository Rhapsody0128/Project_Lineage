class_name BattleUnitVisual
extends Node2D

# =========================================================
# 場上單一角色的畫面呈現(動畫、位置補間)。
# 頭上不常駐顯示名字/HP,也不顯示技能名稱橫幅——放技能時改成左右頭像列
# (BattlePartyRoster)的頭像框高亮+靠近戰場提示,名字與 HP 也是由頭像列常駐顯示。
# 只負責畫面表現,不含任何戰鬥判定邏輯 —— 判定全部來自
# System/battle 的 BattleHero,棋盤座標/像素座標換算則由
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

# 隊長標記:腳下畫一圈金色外框,跟其他角色區分開來
const LEADER_RING_COLOR := Color(1.0, 0.85, 0.2, 1.0)
const LEADER_RING_RADIUS := 20.0
const LEADER_RING_WIDTH := 3.0
const LEADER_RING_CENTER := Vector2(0, -6)

# 測試階段除錯用:角色右下角常駐顯示目前所持武器文字,方便肉眼核對武器與距離/傷害
# 行為是否對得上;正式美術/UI 定案後可以整段移除或改成圖示。
const WEAPON_LABEL_POSITION := Vector2(20, 12)
const WEAPON_LABEL_FONT_SIZE := 12

var battle_hero: BattleHero
var is_enemy: bool
var grid_pos: Vector2i

var sprite: AnimatedSprite2D


## 建立角色顯示(動畫),pixel_pos 為棋盤換算好的初始位置
func setup(p_battle_hero: BattleHero, p_is_enemy: bool, character_scene: PackedScene, pixel_pos: Vector2) -> void:
	battle_hero = p_battle_hero
	is_enemy = p_is_enemy
	grid_pos = battle_hero.grid_pos
	position = pixel_pos
	z_index = grid_pos.y

	var character := character_scene.instantiate()
	add_child(character)
	sprite = character as AnimatedSprite2D

	if sprite == null:
		printerr("角色 Scene 不是 AnimatedSprite2D")
	else:
		sprite.scale = SPRITE_SCALE
		sprite.position = Vector2(0, -8)

		# 我方(左側)面朝右與敵人對戰,敵方(右側)面朝左
		if is_enemy:
			sprite.play("idle_Left")
			sprite.modulate = ENEMY_TINT
		else:
			sprite.play("idle_Right")

	_setup_weapon_label()

	queue_redraw()


## 測試階段除錯用,見 WEAPON_LABEL_POSITION 常數說明
func _setup_weapon_label() -> void:
	var label := Label.new()
	label.text = GameEnums.WEAPON_TYPE_LABELS[battle_hero.hero.weapon]
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
		printerr("找不到動畫：", anim, " / 角色：", battle_hero.name)

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
		z_index = to_grid.y

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
	var label := Label.new()
	label.text = "-%d" % amount
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var font_size := CRIT_DAMAGE_NUMBER_FONT_SIZE if is_critical else DAMAGE_NUMBER_FONT_SIZE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", CRIT_DAMAGE_NUMBER_COLOR if is_critical else DAMAGE_NUMBER_COLOR)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 5)
	label.position = Vector2(-60, -110)
	label.size = Vector2(120, 40)
	label.modulate = Color(1, 1, 1, 0)
	label.z_as_relative = true
	add_child(label)

	var tw := label.create_tween()
	tw.tween_property(label, "modulate:a", 1.0, 0.05)
	tw.parallel().tween_property(label, "position:y", label.position.y - 24.0, DAMAGE_NUMBER_RISE_TIME)
	tw.tween_interval(0.15)
	tw.tween_property(label, "modulate:a", 0.0, 0.25)
	tw.tween_callback(label.queue_free)


## 恢復 HP 時在頭上跳出綠色治療數字,樣式比照 show_damage_number() 但方向相反
## (正數、綠色),讓玩家一眼分辨是傷害還是治療。
func show_heal_number(amount: int) -> void:
	var label := Label.new()
	label.text = "+%d" % amount
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", HEAL_NUMBER_FONT_SIZE)
	label.add_theme_color_override("font_color", HEAL_NUMBER_COLOR)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 5)
	label.position = Vector2(-60, -110)
	label.size = Vector2(120, 40)
	label.modulate = Color(1, 1, 1, 0)
	label.z_as_relative = true
	add_child(label)

	var tw := label.create_tween()
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


func apply_defeated() -> void:
	var tw := create_tween()
	tw.tween_interval(DEATH_FADE_DELAY)
	tw.tween_property(self, "modulate:a", 0.0, DEATH_FADE_TIME)
	tw.tween_callback(func() -> void: visible = false)
