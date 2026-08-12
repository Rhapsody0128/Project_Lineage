extends Control

# =========================================================
# 戰鬥棋盤設定
# =========================================================
const GRID_COLS := 9
const GRID_ROWS := 5
const CELL_SIZE := 70
const BOARD_ORIGIN := Vector2(60, 150)

const COLOR_DEAD_ALPHA := 0.3

const MOVE_TIME := 0.25
const STEP_DELAY := 0.45
const MAX_ROUNDS := 100

# =========================================================
# 新版角色動畫 Scene
#
# animated_sprite_2d.tscn
# 裡面本身就是一個 AnimatedSprite2D
# =========================================================
const CHARACTER_SCENE_PATH := "res://Images/Warrier/animated_sprite_2d.tscn"

const SPRITE_SCALE := Vector2(1.3, 1.3)
const ENEMY_TINT := Color(1.0, 0.55, 0.55)


# =========================================================
# 角色資料
# =========================================================
class UnitData:
	var id: int
	var team: int # 0 = 我方, 1 = 敵方
	var unit_name: String

	var max_hp: int
	var hp: int
	var atk: int
	var def: int
	var spd: int

	var grid_pos: Vector2i
	var alive: bool = true

	# 戰場上的角色 Scene
	var node: Node2D

	# Scene 裡面的 AnimatedSprite2D
	var sprite: AnimatedSprite2D

	var hp_label: Label


var units: Array = []
var is_battling := false
var round_count := 0

# 預載角色 Scene
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

	# ---------------------------------------------------------
	# 載入新版角色動畫 Scene
	# ---------------------------------------------------------
	character_scene = load(CHARACTER_SCENE_PATH)

	if character_scene == null:
		printerr(
			"找不到角色動畫 Scene：",
			CHARACTER_SCENE_PATH
		)
		return

	_setup_units()
	_spawn_unit_visuals()

	_log("按下「開始戰鬥」按鈕，播放戰報！")


# =========================================================
# 畫棋盤
# =========================================================
func _draw() -> void:

	var grid_color := Color(1, 1, 1, 0.25)

	for x in range(GRID_COLS + 1):

		var px := BOARD_ORIGIN.x + x * CELL_SIZE

		draw_line(
			Vector2(px, BOARD_ORIGIN.y),
			Vector2(
				px,
				BOARD_ORIGIN.y + GRID_ROWS * CELL_SIZE
			),
			grid_color,
			1.0
		)

	for y in range(GRID_ROWS + 1):

		var py := BOARD_ORIGIN.y + y * CELL_SIZE

		draw_line(
			Vector2(BOARD_ORIGIN.x, py),
			Vector2(
				BOARD_ORIGIN.x + GRID_COLS * CELL_SIZE,
				py
			),
			grid_color,
			1.0
		)

	# 中線
	var mid_x := BOARD_ORIGIN.x + (GRID_COLS / 2.0) * CELL_SIZE

	draw_line(
		Vector2(mid_x, BOARD_ORIGIN.y),
		Vector2(
			mid_x,
			BOARD_ORIGIN.y + GRID_ROWS * CELL_SIZE
		),
		Color(1, 1, 0, 0.35),
		2.0
	)


# =========================================================
# 初始化角色
# =========================================================
func _setup_units() -> void:

	units.clear()

	var ally_names := [
		"猛虎丸",
		"疾風丸",
		"鐵壁丸",
		"弓月丸",
		"旋風丸"
	]

	var enemy_names := [
		"赤鬼",
		"夜叉",
		"羅刹",
		"餓狼",
		"修羅"
	]

	# ---------------------------------------------------------
	# 我方
	# ---------------------------------------------------------
	for i in range(5):

		var u := UnitData.new()

		u.id = i
		u.team = 0
		u.unit_name = ally_names[i]

		u.max_hp = 100 + i * 5
		u.hp = u.max_hp

		u.atk = 18 + i * 2
		u.def = 6
		u.spd = 10 - i

		u.grid_pos = Vector2i(0, i)

		units.append(u)

	# ---------------------------------------------------------
	# 敵方
	# ---------------------------------------------------------
	for i in range(5):

		var e := UnitData.new()

		e.id = 100 + i
		e.team = 1
		e.unit_name = enemy_names[i]

		e.max_hp = 95 + i * 6
		e.hp = e.max_hp

		e.atk = 17 + i * 2
		e.def = 5
		e.spd = 9 - i

		e.grid_pos = Vector2i(
			GRID_COLS - 1,
			i
		)

		units.append(e)


# =========================================================
# 建立角色顯示
#
# 舊版：
#   Battle 自己建立 AnimatedSprite2D
#   自己切 SpriteSheet
#
# 新版：
#   Battle instantiate animated_sprite_2d.tscn
#   直接使用 Scene 裡面的 AnimatedSprite2D
# =========================================================
func _spawn_unit_visuals() -> void:

	for u in units:

		# -----------------------------------------------------
		# 建立角色外層 Node
		# -----------------------------------------------------
		var root := Node2D.new()

		root.position = _grid_to_center(u.grid_pos)

		units_layer.add_child(root)

		u.node = root


		# -----------------------------------------------------
		# Instantiate 新版角色 Scene
		# -----------------------------------------------------
		var character := character_scene.instantiate()

		root.add_child(character)


		# -----------------------------------------------------
		# 取得 Scene 裡面的 AnimatedSprite2D
		#
		# 因為你的 animated_sprite_2d.tscn：
		#
		# [node name="AnimatedSprite2D" type="AnimatedSprite2D"]
		#
		# 所以 instantiate 後本身就是 AnimatedSprite2D
		# -----------------------------------------------------
		var sprite := character as AnimatedSprite2D

		if sprite == null:

			printerr(
				"角色 Scene 不是 AnimatedSprite2D：",
				CHARACTER_SCENE_PATH
			)

			continue

		u.sprite = sprite


		# -----------------------------------------------------
		# 顯示設定
		# -----------------------------------------------------
		sprite.scale = SPRITE_SCALE
		sprite.position = Vector2(0, -8)


		# -----------------------------------------------------
		# 初始面向
		#
		# 我方 → 朝右
		# 敵方 → 朝左
		# -----------------------------------------------------
		if u.team == 0:

			sprite.play("idle_Right")

		else:

			sprite.play("idle_Left")
			sprite.modulate = ENEMY_TINT


		# -----------------------------------------------------
		# 名稱
		# -----------------------------------------------------
		var name_label := Label.new()

		name_label.text = u.unit_name
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

		name_label.add_theme_font_size_override(
			"font_size",
			11
		)

		name_label.position = Vector2(-32, -56)
		name_label.size = Vector2(64, 16)

		root.add_child(name_label)


		# -----------------------------------------------------
		# HP
		# -----------------------------------------------------
		var hp_label := Label.new()

		hp_label.text = "%d/%d" % [
			u.hp,
			u.max_hp
		]

		hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

		hp_label.add_theme_font_size_override(
			"font_size",
			10
		)

		hp_label.add_theme_color_override(
			"font_color",
			Color(1, 1, 0.6)
		)

		hp_label.position = Vector2(-32, -42)
		hp_label.size = Vector2(64, 14)

		root.add_child(hp_label)

		u.hp_label = hp_label


# =========================================================
# Grid → Pixel
# =========================================================
func _grid_to_pixel(gp: Vector2i) -> Vector2:

	return BOARD_ORIGIN + Vector2(
		gp.x * CELL_SIZE,
		gp.y * CELL_SIZE
	)


func _grid_to_center(gp: Vector2i) -> Vector2:

	return _grid_to_pixel(gp) + Vector2(
		CELL_SIZE / 2.0,
		CELL_SIZE / 2.0
	)


# =========================================================
# 根據方向播放動畫
#
# 新版 SpriteFrames：
#
# walk_Down
# walk_Left
# walk_Right
# walk_Top
#
# attack_Down
# attack_Left
# attack_Right
# attack_Top
# =========================================================
func _play_dir_anim(
	u: UnitData,
	dx: int,
	dy: int,
	prefix: String
) -> void:

	if u.sprite == null:
		return


	var dir_name := "Down"


	# ---------------------------------------------------------
	# 水平
	# ---------------------------------------------------------
	if dx > 0:

		dir_name = "Right"

	elif dx < 0:

		dir_name = "Left"


	# ---------------------------------------------------------
	# 垂直
	# ---------------------------------------------------------
	elif dy > 0:

		dir_name = "Down"

	elif dy < 0:

		dir_name = "Top"


	# ---------------------------------------------------------
	# 動畫名稱
	# ---------------------------------------------------------
	var anim := ""

	if prefix == "attack":

			anim = "attack_%s" % dir_name

	else:

		anim = "%s_%s" % [
			prefix,
			dir_name
		]


	# ---------------------------------------------------------
	# 確認動畫存在
	# ---------------------------------------------------------
	if u.sprite.sprite_frames.has_animation(anim):

		u.sprite.play(anim)

	else:

		printerr(
			"找不到動畫：",
			anim,
			" / 角色：",
			u.unit_name
		)


# =========================================================
# 播放待機動畫
# =========================================================
func _play_idle(u: UnitData, dx: int, dy: int) -> void:

	if u.sprite == null:
		return


	var dir_name := "Down"


	if dx > 0:

		dir_name = "Right"

	elif dx < 0:

		dir_name = "Left"

	elif dy > 0:

		dir_name = "Down"

	elif dy < 0:

		dir_name = "Top"


	var anim := "idle_%s" % dir_name


	if u.sprite.sprite_frames.has_animation(anim):

		u.sprite.play(anim)


# =========================================================
# 按鈕事件
# =========================================================
func _on_start_pressed() -> void:

	if is_battling:
		return

	is_battling = true

	start_button.disabled = true

	status_label.text = "戰鬥中..."

	_run_battle()


func _on_back_pressed() -> void:

	get_tree().change_scene_to_file(
		"res://Secnes/main.tscn"
	)


# =========================================================
# 自動戰鬥主流程
# =========================================================
func _run_battle() -> void:

	round_count = 0

	while _team_alive(0) and _team_alive(1):

		round_count += 1

		if round_count > MAX_ROUNDS:

			_log("已達最大回合數，戰鬥平局。")

			break


		_log(
			"[b]—— 第 %d 回合 ——[/b]"
			% round_count
		)


		var order: Array = units.duplicate()

		order.sort_custom(
			func(a, b):
				return a.spd > b.spd
		)


		for u in order:

			if not u.alive:
				continue

			if not _team_alive(0) or not _team_alive(1):
				break


			var target := _find_nearest_enemy(u)

			if target == null:
				continue


			if _in_attack_range(u, target):

				await _do_attack(
					u,
					target
				)

			else:

				await _do_move(
					u,
					target
				)


			await get_tree().create_timer(
				STEP_DELAY
			).timeout


		await get_tree().process_frame


	is_battling = false

	start_button.disabled = false


	# ---------------------------------------------------------
	# 戰鬥結果
	# ---------------------------------------------------------
	if _team_alive(0) and not _team_alive(1):

		status_label.text = "我方勝利！"

		_log(
			"[color=yellow][b]我方獲得勝利！[/b][/color]"
		)

	elif _team_alive(1) and not _team_alive(0):

		status_label.text = "敵方勝利！"

		_log(
			"[color=red][b]敵方獲得勝利！[/b][/color]"
		)

	else:

		status_label.text = "戰鬥結束"

		_log("戰鬥結束。")


# =========================================================
# 判斷隊伍是否還有人存活
# =========================================================
func _team_alive(team: int) -> bool:

	for u in units:

		if u.team == team and u.alive:

			return true

	return false


# =========================================================
# 找最近敵人
# =========================================================
func _find_nearest_enemy(
	u: UnitData
) -> UnitData:

	var best: UnitData = null
	var best_dist := 999999


	for other in units:

		if other.team != u.team and other.alive:

			var d: int = abs(
				other.grid_pos.x - u.grid_pos.x
			) + abs(
				other.grid_pos.y - u.grid_pos.y
			)


			if d < best_dist:

				best_dist = d
				best = other


	return best


# =========================================================
# 是否進入攻擊範圍
# =========================================================
func _in_attack_range(
	u: UnitData,
	target: UnitData
) -> bool:

	var d: int = abs(
		target.grid_pos.x - u.grid_pos.x
	) + abs(
		target.grid_pos.y - u.grid_pos.y
	)

	return d <= 1


# =========================================================
# 移動
# =========================================================
func _do_move(
	u: UnitData,
	target: UnitData
) -> void:

	var dx := 0
	var dy := 0


	if target.grid_pos.x != u.grid_pos.x:

		dx = sign(
			target.grid_pos.x - u.grid_pos.x
		)

	elif target.grid_pos.y != u.grid_pos.y:

		dy = sign(
			target.grid_pos.y - u.grid_pos.y
		)


	if dx == 0 and dy == 0:
		return


	var new_pos := Vector2i(
		u.grid_pos.x + dx,
		u.grid_pos.y + dy
	)


	if _is_occupied(new_pos):

		return


	# ---------------------------------------------------------
	# 播放對應方向走路動畫
	# ---------------------------------------------------------
	_play_dir_anim(
		u,
		dx,
		dy,
		"walk"
	)


	_log(
		"%s 向前移動"
		% u.unit_name
	)


	# ---------------------------------------------------------
	# 更新位置
	# ---------------------------------------------------------
	u.grid_pos = new_pos


	var tw := create_tween()

	tw.tween_property(
		u.node,
		"position",
		_grid_to_center(new_pos),
		MOVE_TIME
	)


	await tw.finished


	# ---------------------------------------------------------
	# 回到該方向待機
	# ---------------------------------------------------------
	_play_idle(
		u,
		dx,
		dy
	)


# =========================================================
# 判斷格子是否有人
# =========================================================
func _is_occupied(
	gp: Vector2i
) -> bool:

	for other in units:

		if other.alive and other.grid_pos == gp:

			return true

	return false


# =========================================================
# 攻擊
# =========================================================
func _do_attack(
	attacker: UnitData,
	target: UnitData
) -> void:

	var dmg: int = max(
		1,
		attacker.atk - target.def
	)


	var dx: int = sign(
		target.grid_pos.x -
		attacker.grid_pos.x
	)

	var dy: int = sign(
		target.grid_pos.y -
		attacker.grid_pos.y
	)


	# ---------------------------------------------------------
	# 面向目標並播放攻擊
	# ---------------------------------------------------------
	_play_dir_anim(
		attacker,
		dx,
		dy,
		"attack"
	)


	_log(
		"%s 攻擊 %s！"
		% [
			attacker.unit_name,
			target.unit_name
		]
	)


	# ---------------------------------------------------------
	# 等待攻擊動畫播放完成
	# ---------------------------------------------------------
	await attacker.sprite.animation_finished


	# ---------------------------------------------------------
	# 扣血
	# ---------------------------------------------------------
	target.hp -= dmg


	_log(
		"造成 %d 點傷害"
		% dmg
	)


	# ---------------------------------------------------------
	# 攻擊完成 → 待機
	# ---------------------------------------------------------
	_play_idle(
		attacker,
		dx,
		dy
	)


	# ---------------------------------------------------------
	# 判斷死亡
	# ---------------------------------------------------------
	if target.hp <= 0:

		target.hp = 0
		target.alive = false

		target.hp_label.text = (
			"0/%d"
			% target.max_hp
		)


		_log(
			"[color=gray]%s 陣亡[/color]"
			% target.unit_name
		)


		var dtw := create_tween()

		dtw.tween_property(
			target.node,
			"modulate:a",
			COLOR_DEAD_ALPHA,
			0.3
		)


	else:

		target.hp_label.text = (
			"%d/%d"
			% [
				target.hp,
				target.max_hp
			]
		)


# =========================================================
# 戰鬥紀錄
# =========================================================
func _log(msg: String) -> void:

	log_label.append_text(
		msg + "\n"
	)

	log_label.scroll_to_line(
		log_label.get_line_count() - 1
	)
