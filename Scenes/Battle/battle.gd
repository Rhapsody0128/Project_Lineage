extends Control

# =========================================================
# 戰鬥場景整合層(僅負責把 System/battle 算出的結果接到畫面元件上)
#
# 格子大小/初始佈陣/移動與攻擊判定全部由 System/battle 的
# Battle、BattleParty 決定;棋盤格線/地板繪製交給 BattleBoard、
# 角色顯示交給 BattleUnitVisual、戰報交給 BattleLogPanel、
# 左右頭像列交給 BattlePartyRoster,本檔案只負責串接與播放時序。
# =========================================================
const MOVE_TIME := 0.16
const STEP_DELAY := 0.35
# 移動事件(可能一次含多格路徑)播完後的間隔,比其他事件的 STEP_DELAY 短,
# 讓移動節奏更緊湊、不會每次都停頓一大段。
const MOVE_STEP_DELAY := 0.12

# 角色美術尚未完成前,全部角色暫時共用 Warrier 佔位動畫 Scene
const CHARACTER_SCENE_PATH := "res://Images/Warrier/animated_sprite_2d.tscn"

# 頭像用的靜態貼圖(取 Warrier 面向鏡頭的第一張站立圖)
const PORTRAIT_ATLAS_PATH := "res://Images/Warrier/character_walk.png"
const PORTRAIT_REGION := Rect2(0, 0, 32, 46)


var battle: Battle
var visuals: Dictionary = {} # BattleParty -> BattleUnitVisual
var is_battling := false

var character_scene: PackedScene
var portrait_texture: AtlasTexture

@onready var board: BattleBoard = $BoardCanvas
@onready var units_layer: Control = $UnitsLayer
@onready var start_button: Button = $UI/TopBar/StartButton
@onready var back_button: Button = $UI/TopBar/BackButton
@onready var status_label: Label = $UI/StatusPanel/StatusLabel
@onready var log_panel: BattleLogPanel = $UI/LogPanel/LogLabel
@onready var left_roster: BattlePartyRoster = $LeftPartyPanel/LeftPartyList
@onready var right_roster: BattlePartyRoster = $RightPartyPanel/RightPartyList


# =========================================================
# 初始化
# =========================================================
func _ready() -> void:
	character_scene = load(CHARACTER_SCENE_PATH)

	if character_scene == null:
		printerr("找不到角色動畫 Scene：", CHARACTER_SCENE_PATH)
		return

	portrait_texture = AtlasTexture.new()
	portrait_texture.atlas = load(PORTRAIT_ATLAS_PATH)
	portrait_texture.region = PORTRAIT_REGION

	_new_simulation()
	_log("按下「開始戰鬥」按鈕，播放戰報！")


# =========================================================
# 產生一場新的隨機戰鬥
#
# 軍團/部隊/角色資料、初始佈陣與戰鬥判定全部呼叫 System/battle、
# System/troop,本函式只負責把回傳的 BattleParty 對應到畫面元件上。
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

	left_roster.populate(battle.self_parties, false, portrait_texture)
	right_roster.populate(battle.enemy_parties, true, portrait_texture)

	board.queue_redraw()


func _spawn_unit_visual(battle_party: BattleParty, is_enemy: bool) -> void:
	var visual := BattleUnitVisual.new()
	units_layer.add_child(visual)
	visual.setup(battle_party, is_enemy, character_scene, board.grid_to_pixel(battle_party.grid_pos))
	visuals[battle_party] = visual


# =========================================================
# 按鈕事件
# =========================================================
func _on_start_pressed() -> void:
	if is_battling:
		return

	is_battling = true
	start_button.disabled = true
	status_label.text = "戰鬥中..."
	log_panel.clear_log()

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
	get_tree().change_scene_to_file("res://Scenes/main.tscn")


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
				var hit_visual: BattleUnitVisual = visuals.get(event.target)
				if hit_visual != null:
					hit_visual.play_hit_reaction()
					hit_visual.show_damage_number(event.damage_points)
			"soldier_casualty":
				_apply_casualty(event)
			"all_disabled":
				_apply_all_disabled(event)
			"leader_defeated":
				_log("[color=gray]%s總大將 %s 敗退[/color]" % [event.side_label, event.party_name])
			"battle_draw":
				_log("已達最大回合數，戰鬥平局。")

		var delay := MOVE_STEP_DELAY if event.type == "move" else STEP_DELAY
		await get_tree().create_timer(delay).timeout


## 移動:System 層已經算好整趟路徑(event.path,可能為了繞路而轉彎),
## 這裡把棋盤座標換算成像素座標,交給 BattleUnitVisual 連續播放,
## 只記一次「靠近/遠離」訊息,避免多格移動時畫面逐格停頓、洗版同樣的訊息。
func _anim_move(event: Dictionary) -> void:
	var actor: BattleUnitVisual = visuals.get(event.actor)
	if actor == null:
		return

	if event.get("away", false):
		_log("%s 遠離 %s" % [event.actor_name, event.target_name])
	else:
		_log("%s 向 %s 靠近" % [event.actor_name, event.target_name])

	var path_grid: Array = event.path
	var path_pixel: Array = []
	for p in path_grid:
		path_pixel.append(board.grid_to_pixel(p))

	await actor.move_along(path_grid, path_pixel, MOVE_TIME)


func _anim_attack(event: Dictionary) -> void:
	var actor: BattleUnitVisual = visuals.get(event.actor)
	var target: BattleUnitVisual = visuals.get(event.target)
	if actor == null or target == null:
		return

	_log("%s 攻擊 %s！" % [event.actor_name, event.target_name])

	var anim := actor.play_attack_towards(target.grid_pos)
	await actor.wait_for_animation(anim)

	actor.idle_towards(target.grid_pos)


func _anim_skill(event: Dictionary) -> void:
	var actor: BattleUnitVisual = visuals.get(event.actor)
	var target: BattleUnitVisual = visuals.get(event.target)
	if actor == null or target == null:
		return

	_log("%s 使用技能「%s」攻擊 %s！" % [event.actor_name, event.skill_name, event.target_name])

	actor.show_skill_banner(event.skill_name)

	var anim := actor.play_attack_towards(target.grid_pos)
	await actor.wait_for_animation(anim)

	actor.idle_towards(target.grid_pos)


func _apply_casualty(event: Dictionary) -> void:
	var visual: BattleUnitVisual = visuals.get(event.party)
	if visual == null:
		return

	_log("%s 的 %s death: %d and wounded: %d" % [event.party_name, event.soldier_name, event.death_count, event.wounded_count])

	var roster := right_roster if visual.is_enemy else left_roster
	roster.update_hp(event.party, event.remaining_count)


func _apply_all_disabled(event: Dictionary) -> void:
	var visual: BattleUnitVisual = visuals.get(event.party)
	if visual == null:
		return

	_log("[color=gray]%s 全軍覆沒[/color]" % event.party_name)

	visual.apply_all_disabled()

	var roster := right_roster if visual.is_enemy else left_roster
	roster.mark_defeated(event.party)


# =========================================================
# 戰鬥紀錄
# =========================================================
func _log(msg: String) -> void:
	log_panel.log_msg(msg)
