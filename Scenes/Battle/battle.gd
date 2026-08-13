extends Control

# =========================================================
# 戰鬥場景整合層(僅負責把 System/battle 算出的結果接到畫面元件上)
#
# 格子大小/初始佈陣/移動與攻擊判定全部由 System/battle 的
# Battle、BattleHero 決定;棋盤格線/地板繪製交給 BattleBoard、
# 角色顯示交給 BattleUnitVisual、戰報交給 BattleLogPanel、
# 左右頭像列交給 BattlePartyRoster,本檔案只負責串接與播放時序。
# =========================================================
const MOVE_TIME := 0.16
const STEP_DELAY := 0.35
# 移動事件(可能一次含多格路徑)播完後的間隔,比其他事件的 STEP_DELAY 短,
# 讓移動節奏更緊湊、不會每次都停頓一大段。
const MOVE_STEP_DELAY := 0.12
# 沒有傷害計算、也不需要播攻擊/技能動畫的事件類型(移動/遠離、發呆),重播時可以
# 跟同類事件併發播放,不用逐筆排隊等待。
const BATCHABLE_EVENT_TYPES := ["move", "daze"]
# 上述可併發事件連續出現時,一次最多同時播放幾個,加快演示速度。
const EVENT_BATCH_SIZE := 3
# attack/skill 事件後面緊接著的反應事件型別(閃避或受傷),兩者要同時播放,
# 不要分先後拍。
const REACTION_EVENT_TYPES := ["dodge", "damage"]

# 角色美術尚未完成前,全部角色暫時共用 Warrier 佔位動畫 Scene
const CHARACTER_SCENE_PATH := "res://Images/Warrier/animated_sprite_2d.tscn"

# 頭像用的靜態貼圖(取 Warrier 面向鏡頭的第一張站立圖)
const PORTRAIT_ATLAS_PATH := "res://Images/Warrier/character_walk.png"
const PORTRAIT_REGION := Rect2(0, 0, 32, 46)


var battle: Battle
var visuals: Dictionary = {} # BattleHero -> BattleUnitVisual
var is_battling := false
var _pending_batch_actions := 0

# 播放模式:從戰報列表選一份戰報進來重播,而不是自己生一場新的隨機戰鬥。
# battle 已經跑完 start(),這裡只重播固定好的 battle_log,不會重新模擬。
var is_report_playback := false
var report: BattleReport

var character_scene: PackedScene
var portrait_texture: AtlasTexture

@onready var board: BattleBoard = $BoardCanvas
@onready var units_layer: Control = $UnitsLayer
@onready var title_label: Label = $Title
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

	if BattleReportStore.pending_report != null:
		_enter_playback_mode(BattleReportStore.pending_report)
		BattleReportStore.pending_report = null
	else:
		_new_simulation()
		_log("按下「開始戰鬥」按鈕，播放戰報！")


## 進入戰報播放模式:battle 已經是模擬完成、記錄好 battle_log 的舊戰報,
## 不呼叫 battle.start()、只重播;按鈕文字與返回目的地也跟著換成戰報列表情境。
func _enter_playback_mode(p_report: BattleReport) -> void:
	is_report_playback = true
	report = p_report
	battle = report.battle
	battle.reset_for_replay()
	_setup_battlefield()

	title_label.text = "戰報播放：%s" % report.title
	start_button.text = "播放戰報"
	back_button.text = "返回戰報列表"
	_log("按下「播放戰報」按鈕，重現這場戰鬥的完整過程！")


# =========================================================
# 產生一場新的隨機戰鬥
#
# 小隊/角色資料、初始佈陣與戰鬥判定全部呼叫 System/battle、
# System/party,本函式只負責把回傳的 BattleHero 對應到畫面元件上。
# =========================================================
func _new_simulation() -> void:
	battle = BattleController.get_random_battle()
	_setup_battlefield()


## 依目前的 battle(self_heroes/enemy_heroes 的站位與 HP)重建畫面上的單位與頭像列。
## 一般模式(_new_simulation)跟戰報播放模式(_enter_playback_mode/重播)共用。
func _setup_battlefield() -> void:
	for child in units_layer.get_children():
		child.queue_free()
	visuals.clear()

	for battle_hero in battle.self_heroes:
		_spawn_unit_visual(battle_hero, false)

	for battle_hero in battle.enemy_heroes:
		_spawn_unit_visual(battle_hero, true)

	left_roster.populate(battle.self_heroes, false, portrait_texture)
	right_roster.populate(battle.enemy_heroes, true, portrait_texture)

	board.queue_redraw()


func _spawn_unit_visual(battle_hero: BattleHero, is_enemy: bool) -> void:
	var visual := BattleUnitVisual.new()
	units_layer.add_child(visual)
	visual.setup(battle_hero, is_enemy, character_scene, board.grid_to_pixel(battle_hero.grid_pos))
	visuals[battle_hero] = visual


## 依角色所屬陣營回傳對應的頭像列
func _roster_for(battle_hero: BattleHero) -> BattlePartyRoster:
	return right_roster if battle_hero.is_enemy else left_roster


# =========================================================
# 按鈕事件
# =========================================================
func _on_start_pressed() -> void:
	if is_battling:
		return

	is_battling = true
	start_button.disabled = true
	log_panel.clear_log()

	if is_report_playback:
		# 戰報播放:不重新模擬,只是把畫面(站位/HP)歸回開戰當下,
		# 再重播同一份 battle_log——保證第一次跟第二次播放的招式、扣血量完全相同。
		status_label.text = "播放中..."
		battle.reset_for_replay()
		_setup_battlefield()
	else:
		# 注意:這裡不能呼叫 _new_simulation()——battle 是 _ready()(或上一場結束時)
		# 就已經產生好、畫面上正在顯示的那一場,重新產生會讓玩家開戰前看到的隊伍
		# 跟實際開打的隊伍對不上。
		# System 層一次性跑完整場戰鬥模擬,結果寫入 battle.battle_log
		status_label.text = "戰鬥中..."
		battle.start()

	# 場景層依序重播戰報,只負責動畫與畫面呈現
	await _play_battle_log()

	# 播放期間如果場景被切走(節點離開樹但還沒釋放),就不要再碰任何 UI
	# 或重新產生下一場模擬,直接放棄剩下的收尾流程。
	if not is_inside_tree():
		return

	is_battling = false
	start_button.disabled = false
	_announce_result()

	if is_report_playback:
		start_button.text = "重新播放"
		_log("按下「重新播放」按鈕，可以再看一次同樣的過程！")
	else:
		# 為下一次按「開始戰鬥」預先產生新的一場,玩家看到的隊伍就是下次會打的隊伍
		_new_simulation()
		_log("按下「開始戰鬥」按鈕，播放戰報！")


## 10 回合結算:總大將(隊長)死活決定勝負,雙方隊長都撐過 10 回合直接判平手,不比較 HP。
## 直接讀 battle_log 的 battle_end 事件(內含 System 層算好的 result),不用
## battle.self_total_hp/enemy_total_hp 現算——戰報播放前會呼叫 reset_for_replay() 把
## HP 還原成開戰時的滿血,那兩個 getter 讀到的會是還原後的數字,不是戰鬥結束時的數字。
func _announce_result() -> void:
	var totals := _final_totals()
	var self_total: int = totals.self_total
	var enemy_total: int = totals.enemy_total

	match totals.result:
		GameEnums.BattleResultType.SELF_WIN:
			status_label.text = "我方勝利！"
			_log("[color=yellow][b]我方擊敗敵方總大將，我方勝利！(剩餘 HP %d : %d)[/b][/color]" % [self_total, enemy_total])
		GameEnums.BattleResultType.ENEMY_WIN:
			status_label.text = "敵方勝利！"
			_log("[color=red][b]我方總大將陣亡，敵方勝利！(剩餘 HP %d : %d)[/b][/color]" % [self_total, enemy_total])
		_:
			status_label.text = "平手"
			_log("雙方總大將皆存活至第 10 回合，戰鬥平手。(剩餘 HP %d : %d)" % [self_total, enemy_total])


func _final_totals() -> Dictionary:
	for event in battle.battle_log:
		if event.type == "battle_end":
			return {"self_total": event.self_total, "enemy_total": event.enemy_total, "result": event.result}
	return {"self_total": battle.self_total_hp, "enemy_total": battle.enemy_total_hp, "result": battle.result}


func _on_back_pressed() -> void:
	var target := "res://Scenes/BattleReportList/battle_report_list.tscn" if is_report_playback else "res://Scenes/main.tscn"
	get_tree().change_scene_to_file(target)


# =========================================================
# 依序重播 System 層產生的結構化戰報(battle.battle_log)
#
# 連續出現的可併發事件(BATCHABLE_EVENT_TYPES:move/daze,沒有傷害計算、也不用播
# 攻擊/技能動畫)會被抓成一批(最多 EVENT_BATCH_SIZE 個)同時播放,加快演示速度;
# attack/skill 事件則跟緊接在後面的閃避/受傷反應事件合併同時播放(不分先後拍);
# 其餘事件維持逐筆播放。
# =========================================================
func _play_battle_log() -> void:
	var i := 0
	var log_size := battle.battle_log.size()

	while i < log_size:
		# 播放期間場景可能被切走(例如中途按「返回」),節點會離開場景樹但
		# 尚未被釋放,協程恢復執行時若繼續呼叫 get_tree() 會拿到 null 而炸掉,
		# 所以每輪都先確認自己還在樹上,不在就直接放棄剩餘播放。
		if not is_inside_tree():
			return

		var event: Dictionary = battle.battle_log[i]

		if event.type in BATCHABLE_EVENT_TYPES:
			var batch: Array[Dictionary] = [event]
			i += 1
			while i < log_size and battle.battle_log[i].type in BATCHABLE_EVENT_TYPES and batch.size() < EVENT_BATCH_SIZE:
				batch.append(battle.battle_log[i])
				i += 1
			await _play_event_batch(batch)
			await _safe_wait(MOVE_STEP_DELAY)
			continue

		if (event.type == "attack" or event.type == "skill") and i + 1 < log_size and battle.battle_log[i + 1].type in REACTION_EVENT_TYPES:
			# 範圍技能可能一次波及多個目標,緊接著的反應事件(dodge/damage)不保證只有一筆,
			# 把連續出現的都收進同一批,一起套用。
			var reaction_events: Array[Dictionary] = []
			var j := i + 1
			while j < log_size and battle.battle_log[j].type in REACTION_EVENT_TYPES:
				reaction_events.append(battle.battle_log[j])
				j += 1
			await _play_action_with_reaction(event, reaction_events)
			i = j
			await _safe_wait(STEP_DELAY)
			continue

		await _play_single_event(event)
		i += 1
		await _safe_wait(STEP_DELAY)


## 同時播放一批可併發事件:每個各自跑 _play_tracked_event(),用 _pending_batch_actions
## 計數等全部播完才返回,而不是逐個 await 排隊播放。
func _play_event_batch(batch: Array[Dictionary]) -> void:
	_pending_batch_actions = batch.size()
	for event in batch:
		_play_tracked_event(event)
	while _pending_batch_actions > 0:
		await _safe_wait_frame()
		if not is_inside_tree():
			return


## 場景可能在播放期間被切走,節點離開樹但還沒真的被釋放;這兩個 helper
## 先確認還在樹上才呼叫 get_tree(),避免 await 恢復時對 null 呼叫 process_frame
## /create_timer 而噴錯。
func _safe_wait_frame() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame


func _safe_wait(seconds: float) -> void:
	if not is_inside_tree():
		return
	await get_tree().create_timer(seconds).timeout


func _play_tracked_event(event: Dictionary) -> void:
	match event.type:
		"move":
			await _anim_move(event)
		"daze":
			_roster_for(event.actor).pulse_active(event.actor)
			_log("%s 猶豫了一下" % event.actor_name)
	_pending_batch_actions -= 1


func _play_single_event(event: Dictionary) -> void:
	match event.type:
		"battle_start":
			_log("戰鬥開始")
		"round_start":
			_log("[b]—— 第 %d 回合 ——[/b]" % event.round)
		"round_end":
			_log("回合結束")
			await _safe_wait_frame()
		"attack":
			await _anim_attack(event)
		"skill":
			await _anim_skill(event)
		"dodge", "damage":
			_apply_reaction(event)
		"defeated":
			_apply_defeated(event)
		"battle_end":
			_log("戰鬥結束(共 %d 回合)，進行結算。" % event.round)


## attack/skill 動畫與緊接在後的閃避/受傷反應同時播放,不要分先後拍:
## 攻擊方的揮擊動畫一開始播放,就立刻套用防禦方的反應,兩邊動畫同時進行。
## reaction_events 可能不只一筆——範圍技能一次波及多個目標時,每個目標各自的
## 受擊/閃避反應會同時套用在各自的角色身上。
func _play_action_with_reaction(action_event: Dictionary, reaction_events: Array[Dictionary]) -> void:
	var actor: BattleUnitVisual = visuals.get(action_event.actor)
	var target: BattleUnitVisual = visuals.get(action_event.target)
	if actor == null or target == null:
		return

	if action_event.type == "skill":
		_log("%s 使用技能「%s」攻擊 %s！" % [action_event.actor_name, action_event.skill_name, action_event.target_name])
		_roster_for(action_event.actor).pulse_skill(action_event.actor, action_event.skill_name)
		actor.play_skill_light()
	else:
		_log("%s 攻擊 %s！" % [action_event.actor_name, action_event.target_name])
		_roster_for(action_event.actor).pulse_active(action_event.actor)

	var anim := actor.play_attack_towards(target.grid_pos)

	# 不 await,讓反應動畫跟攻擊動畫同時播放
	for reaction_event in reaction_events:
		_apply_reaction(reaction_event)

	await actor.wait_for_animation(anim)
	actor.idle_towards(target.grid_pos)


func _apply_reaction(event: Dictionary) -> void:
	match event.type:
		"dodge":
			_log("%s 閃避了 %s 的攻擊" % [event.target_name, event.actor_name])
			var dodge_visual: BattleUnitVisual = visuals.get(event.target)
			if dodge_visual != null:
				dodge_visual.play_dodge_reaction()
		"damage":
			_log("%s 受到 %d 點傷害" % [event.target_name, event.damage_points])
			var hit_visual: BattleUnitVisual = visuals.get(event.target)
			if hit_visual != null:
				hit_visual.play_hit_reaction()
				hit_visual.show_damage_number(event.damage_points)
				_roster_for(event.target).update_hp(event.target, event.remaining_hp)


## 移動:System 層已經算好整趟路徑(event.path,可能為了繞路而轉彎),
## 這裡把棋盤座標換算成像素座標,交給 BattleUnitVisual 連續播放,
## 只記一次「靠近/遠離」訊息,避免多格移動時畫面逐格停頓、洗版同樣的訊息。
func _anim_move(event: Dictionary) -> void:
	var actor: BattleUnitVisual = visuals.get(event.actor)
	if actor == null:
		return

	_roster_for(event.actor).pulse_active(event.actor)

	if event.get("away", false):
		_log("%s 遠離 %s" % [event.actor_name, event.target_name])
	else:
		_log("%s 向 %s 靠近" % [event.actor_name, event.target_name])

	var path_grid: Array = event.path
	var path_pixel: Array = []
	for p in path_grid:
		path_pixel.append(board.grid_to_pixel(p))

	await actor.move_along(path_grid, path_pixel, MOVE_TIME)


## 沒有緊接反應事件時的備用路徑(理論上 attack/skill 一定緊跟著 dodge/damage,
## 這兩個函式只在極端情況——例如截斷戰報做除錯——才會被單獨呼叫到)。
func _anim_attack(event: Dictionary) -> void:
	var actor: BattleUnitVisual = visuals.get(event.actor)
	var target: BattleUnitVisual = visuals.get(event.target)
	if actor == null or target == null:
		return

	_log("%s 攻擊 %s！" % [event.actor_name, event.target_name])
	_roster_for(event.actor).pulse_active(event.actor)

	var anim := actor.play_attack_towards(target.grid_pos)
	await actor.wait_for_animation(anim)

	actor.idle_towards(target.grid_pos)


func _anim_skill(event: Dictionary) -> void:
	var actor: BattleUnitVisual = visuals.get(event.actor)
	var target: BattleUnitVisual = visuals.get(event.target)
	if actor == null or target == null:
		return

	_log("%s 使用技能「%s」攻擊 %s！" % [event.actor_name, event.skill_name, event.target_name])
	_roster_for(event.actor).pulse_skill(event.actor, event.skill_name)
	actor.play_skill_light()

	var anim := actor.play_attack_towards(target.grid_pos)
	await actor.wait_for_animation(anim)

	actor.idle_towards(target.grid_pos)


func _apply_defeated(event: Dictionary) -> void:
	var visual: BattleUnitVisual = visuals.get(event.party)
	if visual == null:
		return

	_log("[color=gray]%s 戰敗[/color]" % event.party_name)

	visual.apply_defeated()
	_roster_for(event.party).mark_defeated(event.party)


# =========================================================
# 戰鬥紀錄
# =========================================================
func _log(msg: String) -> void:
	log_panel.log_msg(msg)
