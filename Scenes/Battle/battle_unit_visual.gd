class_name BattleUnitVisual
extends Node2D

# =========================================================
# 場上單一角色的畫面呈現(動畫、位置補間)。
# 頭上不常駐顯示名字/兵力,只有放技能時才浮現技能名稱橫幅;
# 名字與血量改由左右頭像列(BattlePartyRoster)常駐顯示。
# 只負責畫面表現,不含任何戰鬥判定邏輯 —— 判定全部來自
# System/battle 的 BattleParty,棋盤座標/像素座標換算則由
# battle.gd(棋盤)負責,本檔案只依照傳進來的結果播放。
# =========================================================

const ENEMY_TINT := Color(1.0, 0.55, 0.55)
const COLOR_DEAD_ALPHA := 0.3
const SPRITE_SCALE := Vector2(1.3, 1.3)

# Warrier 的動畫素材(sprite_frames)全部設為循環播放(loop),
# 代表 AnimatedSprite2D 的 animation_finished 訊號永遠不會觸發,
# 因此攻擊/技能動畫改用「動畫長度計時」等待,不依賴該訊號。
const ATTACK_ANIM_FALLBACK_TIME := 0.4

# 技能名稱浮字顯示時間
const SKILL_BANNER_RISE_TIME := 0.6

# 傷害數字浮字顯示時間
const DAMAGE_NUMBER_RISE_TIME := 0.5

# 受擊反應:閃白顏色與左右震動幅度(像素)
const HIT_FLASH_COLOR := Color(3.0, 3.0, 3.0, 1.0)
const HIT_SHAKE_OFFSET := 6.0

var battle_party: BattleParty
var is_enemy: bool
var grid_pos: Vector2i
var total_max: int

var sprite: AnimatedSprite2D


## 建立角色顯示(動畫),pixel_pos 為棋盤換算好的初始位置
func setup(p_battle_party: BattleParty, p_is_enemy: bool, character_scene: PackedScene, pixel_pos: Vector2) -> void:
	battle_party = p_battle_party
	is_enemy = p_is_enemy
	grid_pos = battle_party.grid_pos
	position = pixel_pos
	z_index = grid_pos.y

	total_max = 0
	for soldier in battle_party.party.soldiers:
		total_max += soldier.soldiers_count_max

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
		printerr("找不到動畫：", anim, " / 角色：", battle_party.name)

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

	await get_tree().create_timer(duration).timeout


## 放招時在角色頭上顯示招式名稱,往上飄並淡出
func show_skill_banner(skill_name: String) -> void:
	var banner := Label.new()
	banner.text = skill_name
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 18)
	banner.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	banner.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	banner.add_theme_constant_override("outline_size", 5)
	banner.position = Vector2(-56, -106)
	banner.size = Vector2(112, 22)
	banner.modulate = Color(1, 1, 1, 0)
	banner.z_as_relative = true
	add_child(banner)

	var tw := banner.create_tween()
	tw.tween_property(banner, "modulate:a", 1.0, 0.1)
	tw.parallel().tween_property(banner, "position:y", banner.position.y - 16.0, SKILL_BANNER_RISE_TIME)
	tw.tween_interval(0.2)
	tw.tween_property(banner, "modulate:a", 0.0, 0.3)
	tw.tween_callback(banner.queue_free)


## 受到傷害時在頭上跳出傷害數字,往上飄並淡出
func show_damage_number(amount: int) -> void:
	var label := Label.new()
	label.text = "-%d" % amount
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 5)
	label.position = Vector2(-40, -96)
	label.size = Vector2(80, 24)
	label.modulate = Color(1, 1, 1, 0)
	label.z_as_relative = true
	add_child(label)

	var tw := label.create_tween()
	tw.tween_property(label, "modulate:a", 1.0, 0.05)
	tw.parallel().tween_property(label, "position:y", label.position.y - 24.0, DAMAGE_NUMBER_RISE_TIME)
	tw.tween_interval(0.15)
	tw.tween_property(label, "modulate:a", 0.0, 0.25)
	tw.tween_callback(label.queue_free)


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


func apply_all_disabled() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", COLOR_DEAD_ALPHA, 0.3)
