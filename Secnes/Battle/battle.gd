extends Control

# =========================================================
# 戰鬥棋盤設定(僅供本場景畫面呈現使用,不含任何戰鬥判定邏輯)
#
# 格子大小/初始佈陣/移動與攻擊判定全部由 System/battle 的
# Battle、BattleParty 決定,本檔案只依照它們算出的結果畫出來。
# =========================================================
const GRID_COLS := Battle.GRID_COLS
const GRID_ROWS := Battle.GRID_ROWS

# 45 度斜角(等角視圖)格子投影:寬高比 2:1 是常見 SLG 戰場的斜角比例,
# 若想要更接近正 45 度的菱形,把 TILE_HEIGHT 調成等於 TILE_WIDTH 即可。
const TILE_WIDTH := 64.0
const TILE_HEIGHT := 32.0
const BOARD_ORIGIN := Vector2(460, 60)

const COLOR_DEAD_ALPHA := 0.3

const MOVE_TIME := 0.25
const STEP_DELAY := 0.35

# Warrier 的動畫素材(sprite_frames)全部設為循環播放(loop),
# 代表 AnimatedSprite2D 的 animation_finished 訊號永遠不會觸發,
# 因此攻擊/技能動畫改用「動畫長度計時」等待,不依賴該訊號。
const ATTACK_ANIM_FALLBACK_TIME := 0.4

# 技能名稱浮字顯示時間
const SKILL_BANNER_RISE_TIME := 0.6

# =========================================================
# 角色動畫 Scene(角色美術尚未完成前,全部角色暫時共用 Warrier 佔位)
# =========================================================
const CHARACTER_SCENE_PATH := "res://Images/Warrier/animated_sprite_2d.tscn"

const SPRITE_SCALE := Vector2(1.3, 1.3)
const ENEMY_TINT := Color(1.0, 0.55, 0.55)


# =========================================================
# 場景端角色顯示包裝
#
# 只保存畫面呈現所需的節點/位置資訊,grid_pos 是「重播進度到目前為止」
# 的座標快照,用來計算動畫方向,和 System 端已經跑完全場的最終座標分開。
# 真正的戰鬥數值與判定邏輯全部來自 System/battle 的 BattleParty,
# 本檔案只負責把 System 算出來的結果畫出來。
# =========================================================
class UnitVisual:
	var battle_party: BattleParty
	var is_enemy: bool
	var grid_pos: Vector2i
	var node: Node2D
	var sprite: AnimatedSprite2D
	var name_label: Label
	var troop_label: Label
	var total_max: int


var battle: Battle
var visuals: Dictionary = {} # BattleParty -> UnitVisual
var is_battling := false

var character_scene: PackedScene

@onready var units_layer: Control = $UnitsLayer
@onready var start_button: Button = $UI/TopBar/StartButton
@onready var back_button: Button = $UI/TopBar/BackButton
@onready var status_label: Label = $UI/StatusLabel
@onready var log_label: RichTextLabel = $UI/LogPanel/LogLabel


# =========================================================
# 初始化
# =========================================================
func _ready() -> void:
	character_scene = load(CHARACTER_SCENE_PATH)

	if character_scene == null:
		printerr("找不到角色動畫 Scene：", CHARACTER_SCENE_PATH)
		return

	_new_simulation()
	_log("按下「開始戰鬥」按鈕，播放戰報！")


# =========================================================
# 畫棋盤(45 度斜角格線)
#
# _grid_to_pixel 是線性變換,所以「格線」在投影後仍然是直線,
# 只是不再與畫面水平/垂直對齊,而是呈現斜角菱形棋盤的樣子。
# =========================================================
func _draw() -> void:
	var grid_color := Color(1, 1, 1, 0.25)

	for x in range(GRID_COLS + 1):
		draw_line(
			_grid_to_pixel(Vector2i(x, 0)),
			_grid_to_pixel(Vector2i(x, GRID_ROWS)),
			grid_color,
			1.0
		)

	for y in range(GRID_ROWS + 1):
		draw_line(
			_grid_to_pixel(Vector2i(0, y)),
			_grid_to_pixel(Vector2i(GRID_COLS, y)),
			grid_color,
			1.0
		)

	# 中線,標示雙方交戰的中央地帶
	var mid_y := GRID_ROWS / 2
	draw_line(
		_grid_to_pixel(Vector2i(0, mid_y)),
		_grid_to_pixel(Vector2i(GRID_COLS, mid_y)),
		Color(1, 1, 0, 0.35),
		2.0
	)


# =========================================================
# 產生一場新的隨機戰鬥
#
# 軍團/部隊/角色資料、初始佈陣與戰鬥判定全部呼叫 System/battle、
# System/troop,本函式只負責把回傳的 BattleParty 對應到畫面上的顯示節點。
# =========================================================
func _new_simulation() -> void:
	for child in units_layer.get_children():
		child.queue_free()
	visuals.clear()

	battle = BattleController.get_random_battle()

	for battle_party in battle.self_parties:
		_spawn_unit_visual(battle_party, false)

	for battle_party in battle.enemy_parties:
		_spawn_unit_visual(battle_party, true)

	queue_redraw()


# =========================================================
# 建立角色顯示
# =========================================================
func _spawn_unit_visual(battle_party: BattleParty, is_enemy: bool) -> void:
	var visual := UnitVisual.new()
	visual.battle_party = battle_party
	visual.is_enemy = is_enemy
	visual.grid_pos = battle_party.grid_pos # 此時戰鬥尚未開打,即為初始佈陣座標

	visual.total_max = 0
	for soldier in battle_party.party.soldiers:
		visual.total_max += soldier.soldiers_count_max

	var root := Node2D.new()
	root.position = _grid_to_pixel(visual.grid_pos)
	root.z_index = visual.grid_pos.y
	units_layer.add_child(root)
	visual.node = root

	var character := character_scene.instantiate()
	root.add_child(character)

	var sprite := character as AnimatedSprite2D

	if sprite == null:
		printerr("角色 Scene 不是 AnimatedSprite2D：", CHARACTER_SCENE_PATH)
	else:
		visual.sprite = sprite
		sprite.scale = SPRITE_SCALE
		sprite.position = Vector2(0, -8)

		# 我方(下方)面朝上與敵人對戰,敵方(上方)面朝下
		if is_enemy:
			sprite.play("idle_Down")
			sprite.modulate = ENEMY_TINT
		else:
			sprite.play("idle_Top")

	var name_label := Label.new()
	name_label.text = battle_party.name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.position = Vector2(-32, -56)
	name_label.size = Vector2(64, 16)
	root.add_child(name_label)
	visual.name_label = name_label

	var troop_label := Label.new()
	troop_label.text = "%d/%d" % [battle_party.total_soldier_count, visual.total_max]
	troop_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	troop_label.add_theme_font_size_override("font_size", 10)
	troop_label.add_theme_color_override("font_color", Color(1, 1, 0.6))
	troop_label.position = Vector2(-32, -42)
	troop_label.size = Vector2(64, 14)
	root.add_child(troop_label)
	visual.troop_label = troop_label

	visuals[battle_party] = visual


# =========================================================
# Grid → Pixel(45 度斜角投影)
# =========================================================
func _grid_to_pixel(gp: Vector2i) -> Vector2:
	return BOARD_ORIGIN + Vector2(
		(gp.x - gp.y) * (TILE_WIDTH / 2.0),
		(gp.x + gp.y) * (TILE_HEIGHT / 2.0)
	)


# =========================================================
# 根據方向播放動畫
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
func _play_dir_anim(visual: UnitVisual, dir: Vector2i, prefix: String) -> String:
	var anim := "%s_%s" % [prefix, _dir_name(dir)]

	if visual.sprite == null:
		return anim

	if visual.sprite.sprite_frames.has_animation(anim):
		visual.sprite.play(anim)
	else:
		printerr("找不到動畫：", anim, " / 角色：", visual.name_label.text)

	return anim


func _play_idle(visual: UnitVisual, dir: Vector2i) -> void:
	if visual.sprite == null:
		return

	var anim := "idle_%s" % _dir_name(dir)

	if visual.sprite.sprite_frames.has_animation(anim):
		visual.sprite.play(anim)


## 動畫素材為循環播放,animation_finished 不會觸發,改用長度計時等待
func _wait_for_animation(visual: UnitVisual, anim_name: String) -> void:
	var duration := ATTACK_ANIM_FALLBACK_TIME

	if visual.sprite != null and visual.sprite.sprite_frames != null and visual.sprite.sprite_frames.has_animation(anim_name):
		var frame_count := visual.sprite.sprite_frames.get_frame_count(anim_name)
		var speed := visual.sprite.sprite_frames.get_animation_speed(anim_name)
		if speed > 0.0 and frame_count > 0:
			duration = frame_count / speed

	await get_tree().create_timer(duration).timeout


# =========================================================
# 按鈕事件
# =========================================================
func _on_start_pressed() -> void:
	if is_battling:
		return

	is_battling = true
	start_button.disabled = true
	status_label.text = "戰鬥中..."
	log_label.clear()

	_new_simulation()

	# System 層一次性跑完整場戰鬥模擬,結果寫入 battle.battle_log
	battle.start()

	# 場景層依序重播戰報,只負責動畫與畫面呈現
	await _play_battle_log()

	is_battling = false
	start_button.disabled = false

	if battle.enemy_party_leader.total_soldier_is_disabled and not battle.self_party_leader.total_soldier_is_disabled:
		status_label.text = "我方勝利！"
		_log("[color=yellow][b]我方獲得勝利！[/b][/color]")
	elif battle.self_party_leader.total_soldier_is_disabled and not battle.enemy_party_leader.total_soldier_is_disabled:
		status_label.text = "敵方勝利！"
		_log("[color=red][b]敵方獲得勝利！[/b][/color]")
	else:
		status_label.text = "戰鬥結束"
		_log("戰鬥結束。")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Secnes/main.tscn")


# =========================================================
# 依序重播 System 層產生的結構化戰報(battle.battle_log)
# =========================================================
func _play_battle_log() -> void:
	for event in battle.battle_log:
		match event.type:
			"battle_start":
				_log("戰鬥開始")
			"round_start":
				_log("[b]—— 第 %d 回合 ——[/b]" % event.round)
			"round_end":
				_log("回合結束")
				await get_tree().process_frame
			"move":
				await _anim_move(event)
			"attack":
				await _anim_attack(event)
			"skill":
				await _anim_skill(event)
			"dodge":
				_log("%s 閃避了 %s 的攻擊" % [event.target_name, event.actor_name])
			"daze":
				_log("%s 猶豫了一下" % event.actor_name)
			"damage":
				_log("%s 受到 %d 點傷害" % [event.target_name, event.damage_points])
			"soldier_casualty":
				_apply_casualty(event)
			"all_disabled":
				_apply_all_disabled(event)
			"leader_defeated":
				_log("[color=gray]%s總大將 %s 敗退[/color]" % [event.side_label, event.party_name])
			"battle_draw":
				_log("已達最大回合數，戰鬥平局。")

		await get_tree().create_timer(STEP_DELAY).timeout


## 移動:System 層已經算好目的地格子(event.from / event.to),
## 這裡只負責把角色從舊格子的畫面座標補間到新格子的畫面座標。
func _anim_move(event: Dictionary) -> void:
	var actor: UnitVisual = visuals.get(event.actor)
	if actor == null:
		return

	_log("%s 向 %s 靠近" % [event.actor_name, event.target_name])

	var to_pos: Vector2i = event.to
	var dir: Vector2i = to_pos - actor.grid_pos

	_play_dir_anim(actor, dir, "walk")

	actor.grid_pos = to_pos
	actor.node.z_index = to_pos.y

	var tw := actor.node.create_tween()
	tw.tween_property(actor.node, "position", _grid_to_pixel(to_pos), MOVE_TIME)
	await tw.finished

	_play_idle(actor, dir)


func _anim_attack(event: Dictionary) -> void:
	var actor: UnitVisual = visuals.get(event.actor)
	var target: UnitVisual = visuals.get(event.target)
	if actor == null or target == null:
		return

	_log("%s 攻擊 %s！" % [event.actor_name, event.target_name])

	var dir: Vector2i = target.grid_pos - actor.grid_pos
	var anim := _play_dir_anim(actor, dir, "attack")
	await _wait_for_animation(actor, anim)

	_play_idle(actor, dir)


func _anim_skill(event: Dictionary) -> void:
	var actor: UnitVisual = visuals.get(event.actor)
	var target: UnitVisual = visuals.get(event.target)
	if actor == null or target == null:
		return

	_log("%s 使用技能「%s」攻擊 %s！" % [event.actor_name, event.skill_name, event.target_name])

	_show_skill_banner(actor, event.skill_name)

	var dir: Vector2i = target.grid_pos - actor.grid_pos
	var anim := _play_dir_anim(actor, dir, "attack")
	await _wait_for_animation(actor, anim)

	_play_idle(actor, dir)


## 放招時在角色頭上顯示招式名稱,往上飄並淡出
func _show_skill_banner(visual: UnitVisual, skill_name: String) -> void:
	var banner := Label.new()
	banner.text = skill_name
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 16)
	banner.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	banner.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	banner.add_theme_constant_override("outline_size", 4)
	banner.position = Vector2(-48, -78)
	banner.size = Vector2(96, 20)
	banner.modulate = Color(1, 1, 1, 0)
	banner.z_as_relative = true
	visual.node.add_child(banner)

	var tw := banner.create_tween()
	tw.tween_property(banner, "modulate:a", 1.0, 0.1)
	tw.parallel().tween_property(banner, "position:y", banner.position.y - 16.0, SKILL_BANNER_RISE_TIME)
	tw.tween_interval(0.2)
	tw.tween_property(banner, "modulate:a", 0.0, 0.3)
	tw.tween_callback(banner.queue_free)


func _apply_casualty(event: Dictionary) -> void:
	var visual: UnitVisual = visuals.get(event.party)
	if visual == null:
		return

	_log("%s 的 %s death: %d and wounded: %d" % [event.party_name, event.soldier_name, event.death_count, event.wounded_count])

	visual.troop_label.text = "%d/%d" % [event.remaining_count, visual.total_max]


func _apply_all_disabled(event: Dictionary) -> void:
	var visual: UnitVisual = visuals.get(event.party)
	if visual == null:
		return

	_log("[color=gray]%s 全軍覆沒[/color]" % event.party_name)

	visual.troop_label.text = "0/%d" % visual.total_max

	var dtw := visual.node.create_tween()
	dtw.tween_property(visual.node, "modulate:a", COLOR_DEAD_ALPHA, 0.3)


# =========================================================
# 戰鬥紀錄
# =========================================================
func _log(msg: String) -> void:
	log_label.append_text(msg + "\n")
	log_label.scroll_to_line(log_label.get_line_count() - 1)
