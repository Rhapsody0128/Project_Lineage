extends Control

# =========================================================
# 戰鬥場景整合層(僅負責把 System/battle 算出的結果接到畫面元件上)
#
# 格子大小/初始佈陣/移動與攻擊判定全部由 System/battle 的
# Battle、BattleCharacter 決定;棋盤格線/地板繪製交給 BattleBoard、
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
const BATCHABLE_EVENT_TYPES: Array[GameEnums.BattleEventType] = [
	GameEnums.BattleEventType.MOVE, GameEnums.BattleEventType.DAZE,
]
# 上述可併發事件連續出現時,一次最多同時播放幾個,加快演示速度。
const EVENT_BATCH_SIZE := 3
# attack/skill 事件後面緊接著的反應事件型別(閃避、受傷、治療、素質增益/減益),
# 都要跟前面的 attack/skill 同時播放,不要分先後拍——C. 治癒/D. 大將之風/E. 降咒
# 都是「skill 事件後面緊接一串 heal 或 stat_effect」的結構,跟 AoE 傷害技能同一套。
const REACTION_EVENT_TYPES: Array[GameEnums.BattleEventType] = [
	GameEnums.BattleEventType.DODGE, GameEnums.BattleEventType.DAMAGE,
	GameEnums.BattleEventType.HEAL, GameEnums.BattleEventType.STAT_EFFECT,
]

# 角色美術尚未完成前,全部角色暫時共用 Warrier 佔位動畫 Scene
const CHARACTER_SCENE_PATH := "res://Images/Warrier/animated_sprite_2d.tscn"

# 頭像用的靜態貼圖(取 Warrier 面向鏡頭的第一張站立圖)
const PORTRAIT_ATLAS_PATH := "res://Images/Warrier/character_walk.png"
const PORTRAIT_REGION := Rect2(0, 0, 32, 46)

# 戰報改成點擊 LogToggleButton 彈出 LogDialog(見 _on_log_toggle_button_pressed()),
# 不再佔用版面、也不會讓戰場跟著縮放——戰場(BoardCanvas + UnitsLayer,格線/地板/
# 場上角色全部一起)固定用 Control.scale 放大到填滿版面,永遠貼著同一顆 pivot 錨點
# (戰場面板左上角)長大,不會因為戰報開關而改變大小,場上其他元件(RoundLabel 等)
# 才能用固定座標對齊,不用另外處理兩套版面。
const BOARD_PIVOT := Vector2(140.0, 140.0)
const BOARD_BASE_WIDTH := 828.0
const BOARD_BASE_HEIGHT := 480.0
const BOARD_SCALE := 1.5
const RIGHT_PARTY_WIDTH := 112.0
const RIGHT_PARTY_GAP := 8.0
const RIGHT_PARTY_LEFT := BOARD_PIVOT.x + BOARD_BASE_WIDTH * BOARD_SCALE + RIGHT_PARTY_GAP

# 奧義施放/生效時,在戰場正中央浮出的大字(見 _show_ultimate_banner())——不是某個
# 角色頭像旁邊喊招式名稱那一套(那是 Skill 的表現方式,見 BattlePartyRoster.pulse_skill())。
const ULTIMATE_BANNER_FONT_SIZE := 40
const ULTIMATE_BANNER_COLOR := Color(1.0, 0.85, 0.35, 1.0)
const ULTIMATE_BANNER_OUTLINE_COLOR := Color(0.15, 0.05, 0.02, 0.9)
const ULTIMATE_BANNER_OUTLINE_SIZE := 8
const ULTIMATE_BANNER_FADE_TIME := 0.3
const ULTIMATE_BANNER_HOLD_TIME := 1.1

# 結果 Dialog 的勝/敗/平文字顏色,跟 battle_report_list.gd/battle_report_stats.gd
# 同一組配色,讀在羊皮紙底上都還夠亮——不要沿用舊版「yellow/red/white」字串,
# 白色在淺色羊皮紙底上幾乎看不見。
const WIN_COLOR := Color(0.1, 0.9, 0.1)
const LOSE_COLOR := Color(0.9, 0.1, 0.1)
const DRAW_COLOR := Color(0.0, 0.0, 0.0)


var battle: Battle
var visuals: Dictionary = {} # BattleCharacter -> BattleUnitVisual
var is_battling := false
var _pending_batch_actions := 0

## _run_battle_realtime() 那個協程可能還卡在某個 await(動畫/計時器)沒有真正結束,
## is_battling 只是告訴它「該收尾了」,但它要等目前正在播的那個事件動畫播完才會真的
## return。_realtime_active 標記它是否還「活著」,重播按鈕(_on_dialog_replay_pressed())
## 要等它真的結束、發出 realtime_stopped 之後才能重置戰場——否則舊協程醒來時還會拿
## 已經被 reset_for_replay()/_setup_battlefield() 換掉的站位/角色節點繼續播,畫面
## 看起來像兩場戰報同時在跑、角色亂跳。
signal realtime_stopped
var _realtime_active := false
var _replay_pending := false

# 播放模式:從戰報列表選一份戰報進來重播,而不是自己生一場新的隨機戰鬥。
# battle 已經跑完 start(),這裡只重播固定好的 battle_log,不會重新模擬。
var report: BattleReport

# 戰鬥模式(見 GameEnums.BattleMode):AUTO 一次性模擬完直接重播(戰報/自動模式,
# _run_battle_playback());REALTIME 逐回合跑,回合間開放玩家手動施放奧義
# (_run_battle_realtime())。只有 _new_simulation()(自己生一場新戰鬥)這條路徑會讀
# BattleReportStore.pending_battle_mode 決定;戰報播放/PartyEdit 帶編成兩條路徑目前
# 固定走 AUTO。
var battle_mode: GameEnums.BattleMode = GameEnums.BattleMode.AUTO
# _run_battle_realtime() 已經播放到 battle.battle_log 的第幾筆(不含),下一次只播放
# 這個索引之後新增的事件——逐回合跑,battle_log 是持續增長的,不能每次都從頭重播。
var _played_log_index := 0

var character_scene: PackedScene
var portrait_texture: AtlasTexture

# 側邊頭像列、戰場(BoardCanvas/UnitsLayer)、奧義面板全部收在 BattlefieldPanel 底下
# 整理成同一個容器(見 battle.tscn),彼此的相對位置/縮放邏輯集中寫在
# _apply_board_layout() 一處,不會散落在場景樹各處各自為政。
@onready var board: BattleBoard = $BattlefieldPanel/BoardCanvas
@onready var units_layer: Control = $BattlefieldPanel/UnitsLayer
@onready var title_label: Label = $Title
@onready var round_label: Label = $RoundLabel
@onready var pause_button: Button = $UI/TopBar/PauseButton
@onready var skip_button: Button = $UI/TopBar/SkipButton
@onready var back_button: Button = $UI/TopBar/BackButton
@onready var log_toggle_button: Button = $UI/TopBar/LogToggleButton
@onready var log_dialog: Control = $LogDialog
@onready var log_dialog_close_button: Button = $LogDialog/Panel/VBox/TitleRow/CloseButton
@onready var log_panel: BattleLogPanel = $LogDialog/Panel/VBox/LogLabel
@onready var left_roster: BattlePartyRoster = $BattlefieldPanel/LeftPartyPanel/LeftPartyCenter/LeftPartyList
@onready var right_party_panel: Panel = $BattlefieldPanel/RightPartyPanel
@onready var right_roster: BattlePartyRoster = $BattlefieldPanel/RightPartyPanel/RightPartyCenter/RightPartyList
@onready var result_dialog: Control = $ResultDialog
@onready var result_label: Label = $ResultDialog/Panel/VBox/ResultLabel
@onready var result_detail_label: Label = $ResultDialog/Panel/VBox/DetailLabel
@onready var replay_button: Button = $ResultDialog/Panel/VBox/ButtonRow/ReplayButton
@onready var dialog_back_button: Button = $ResultDialog/Panel/VBox/ButtonRow/DialogBackButton
@onready var ultimate_panel: BattleUltimatePanel = $BattlefieldPanel/UltimatePanel


# =========================================================
# 初始化
# =========================================================
func _ready() -> void:
	# 場上角色本人(BattleUnitVisual)靠 Area2D 判定點擊(見 _setup_click_area()),
	# 預設關閉的 2D 物理揀選要開啟這個事件才會送到 Area2D.input_event。
	get_viewport().physics_object_picking = true

	for button in [pause_button, skip_button, back_button, log_toggle_button, replay_button, dialog_back_button, log_dialog_close_button]:
		UiStyle.apply_wood_plaque_button(button, 16.0, 8.0)
		button.add_theme_font_size_override("font_size", 18)

	# LogDialog/ResultDialog 兩個浮出的彈窗比照 CharacterPanel/AskBattle,換成羊皮紙木框
	# 面板(取代原本的深藍色系 StyleBoxFlat),文字顏色跟著 UiStyle.PARCHMENT_TEXT_COLOR
	# 那一套(見 .tscn 內 TitleLabel/LogLabel/DetailLabel 的 font_color),跟其他彈出式
	# 對話框保持一致。
	UiStyle.apply_parchment_panel($LogDialog/Panel, 800.0, 700.0, 60.0, 50.0, 80.0, 50.0)
	UiStyle.apply_parchment_panel($ResultDialog/Panel, 440.0, 300.0, 20.0, 16.0, 20.0, 16.0)

	log_toggle_button.pressed.connect(_on_log_toggle_button_pressed)
	log_dialog_close_button.pressed.connect(_on_log_dialog_close_pressed)
	_apply_board_layout()

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
	elif BattleReportStore.pending_self_party != null and BattleReportStore.pending_enemy_party != null:
		var self_party := BattleReportStore.pending_self_party
		var enemy_party := BattleReportStore.pending_enemy_party
		BattleReportStore.pending_self_party = null
		BattleReportStore.pending_enemy_party = null
		_new_simulation_with_parties(self_party, enemy_party)
	elif BattleReportStore.pending_self_party != null:
		var self_party := BattleReportStore.pending_self_party
		BattleReportStore.pending_self_party = null
		_new_simulation_with_self_party(self_party)
	else:
		_new_simulation()


## 進入戰報播放模式:battle 已經是模擬完成、記錄好 battle_log 的舊戰報,
## 不呼叫 battle.start()、只重播;返回目的地也跟著換成戰報列表情境。
func _enter_playback_mode(p_report: BattleReport) -> void:
	report = p_report
	battle = report.battle
	battle.reset_for_replay()
	_setup_battlefield()

	title_label.text = "戰報播放：%s" % report.title
	back_button.text = "返回戰報列表"
	_log("進入戰報播放，自動重現這場戰鬥的完整過程！")

	_run_battle_playback(false)


# =========================================================
# 產生一場新的隨機戰鬥
#
# 小隊/角色資料、初始佈陣與戰鬥判定全部呼叫 System/battle、
# System/party,本函式只負責把回傳的 BattleCharacter 對應到畫面元件上。
# =========================================================
func _new_simulation() -> void:
	battle_mode = BattleReportStore.pending_battle_mode
	BattleReportStore.pending_battle_mode = GameEnums.BattleMode.AUTO
	battle = BattleController.get_random_battle()
	_setup_battlefield()
	title_label.text = WorldTimeStore.get_display_string()
	if battle_mode == GameEnums.BattleMode.REALTIME:
		_run_battle_realtime()
	else:
		_run_battle_playback(true)


## PartyEdit「以現在編成開始戰鬥」用:玩家編好的小隊對上隨機敵方小隊,
## 其餘流程(佈陣/播放)跟一般隨機戰鬥共用同一套。
func _new_simulation_with_self_party(self_party: Party) -> void:
	battle_mode = BattleReportStore.pending_battle_mode
	BattleReportStore.pending_battle_mode = GameEnums.BattleMode.AUTO
	battle = BattleController.get_battle_with_self_party(self_party)
	_setup_battlefield()
	title_label.text = WorldTimeStore.get_display_string()
	back_button.text = "返回隊伍編輯"
	if battle_mode == GameEnums.BattleMode.REALTIME:
		_run_battle_realtime()
	else:
		_run_battle_playback(true)


## 雙方小隊都是呼叫端指定的特定隊伍(不是隨機敵方),其餘流程(佈陣/播放)跟一般隨機
## 戰鬥共用同一套。兩處呼叫端會走到這裡:AskBattle「選否」(見 Scenes/BattleUtil/
## ask_battle.gd)、PartyEdit「加強DEMO戰鬥角色」開關按下時(敵方換成呼叫端自己先用
## 較高 RankType 生好的小隊,見 Scenes/PartyEdit/party_edit.gd 的 _on_start_battle_pressed())。
func _new_simulation_with_parties(self_party: Party, enemy_party: Party) -> void:
	battle_mode = BattleReportStore.pending_battle_mode
	BattleReportStore.pending_battle_mode = GameEnums.BattleMode.AUTO
	battle = BattleController.get_battle(self_party, enemy_party)
	_setup_battlefield()
	title_label.text = WorldTimeStore.get_display_string()
	if battle_mode == GameEnums.BattleMode.REALTIME:
		_run_battle_realtime()
	else:
		_run_battle_playback(true)


## 依目前的 battle(self_characteres/enemy_characteres 的站位與 HP)重建畫面上的單位與頭像列。
## 一般模式(_new_simulation)跟戰報播放模式(_enter_playback_mode/重播)共用。
func _setup_battlefield() -> void:
	for child in units_layer.get_children():
		child.queue_free()
	visuals.clear()

	for battle_character in battle.self_characteres:
		_spawn_unit_visual(battle_character, false)

	for battle_character in battle.enemy_characteres:
		_spawn_unit_visual(battle_character, true)

	left_roster.populate(battle.self_characteres, false, portrait_texture)
	right_roster.populate(battle.enemy_characteres, true, portrait_texture)

	round_label.text = "回合 1"
	board.queue_redraw()


func _spawn_unit_visual(battle_character: BattleCharacter, is_enemy: bool) -> void:
	var visual := BattleUnitVisual.new()
	units_layer.add_child(visual)
	visual.setup(battle_character, is_enemy, character_scene, board.grid_to_pixel(battle_character.grid_pos))
	visuals[battle_character] = visual


## 依角色所屬陣營回傳對應的頭像列
func _roster_for(battle_character: BattleCharacter) -> BattlePartyRoster:
	return right_roster if battle_character.is_enemy else left_roster


# =========================================================
# 戰場版面(固定不變)/戰報 Dialog 開關
# =========================================================
## 戰場(BoardCanvas + UnitsLayer,格線/地板/場上角色全部一起;右側頭像列;奧義面板)
## 版面固定,只在 _ready() 呼叫一次——戰報改用 LogDialog 彈出顯示(見
## _on_log_toggle_button_pressed()),不再佔用版面,戰場不需要跟著開關戰報縮放,
## RoundLabel 等其他元件才能用固定座標對齊,不會因為戰報開關而跑位。
func _apply_board_layout() -> void:
	for node in [board, units_layer]:
		node.pivot_offset = BOARD_PIVOT
		node.scale = Vector2.ONE * BOARD_SCALE

	right_party_panel.position.x = RIGHT_PARTY_LEFT
	right_party_panel.size.x = RIGHT_PARTY_WIDTH

	ultimate_panel.position.x = BOARD_PIVOT.x
	ultimate_panel.size.x = BOARD_BASE_WIDTH * BOARD_SCALE


func _on_log_toggle_button_pressed() -> void:
	log_dialog.visible = true


func _on_log_dialog_close_pressed() -> void:
	log_dialog.visible = false


# =========================================================
# 按鈕事件
# =========================================================
## 結果 Dialog 的「重播」按鈕:不管是一般模式還是戰報播放模式,這裡都只是把同一份
## battle.battle_log(已經模擬完成、固定不變)重播一次,絕對不能呼叫 battle.start()
## 再模擬一次——那樣招式/骰值全部重骰,就不是「重播」了。
func _on_dialog_replay_pressed() -> void:
	if is_battling or _replay_pending:
		return
	# 攔住下面 await 期間的第二次點擊:不能用 is_battling 頂替這個用途——舊的
	# _run_battle_realtime() 協程正是靠 is_battling 是否還是 false 判斷自己該不該
	# 收尾(見該函式內的檢查),提前把它改回 true 會讓舊協程誤以為戰鬥還在繼續,
	# 永遠不會發出 realtime_stopped,下面的 await 就卡死,按下去毫無反應。
	_replay_pending = true
	if _realtime_active:
		await realtime_stopped
	_replay_pending = false
	await _run_battle_playback(false)


## 實際跑一場(should_simulate=true)或重播一場(should_simulate=false)戰鬥,並負責
## 前後的 UI 狀態切換。一進場(_new_simulation()/_enter_playback_mode())或按「重播」
## 都會呼叫這裡,不需要玩家手動按開始鈕——已經沒有這顆按鈕。刻意不在播放結束後預先
## 呼叫 _new_simulation() 產生下一場——那樣做會在結果 Dialog 彈出的同時,把畫面上的
## 角色站位整個換成「下一場」的初始佈陣,玩家會看到角色瞬間跳回起始位置,不是想要的
## 「定格在戰鬥結束當下」。下一場要等玩家離開這個場景、重新進來(_ready())時才會產生。
func _run_battle_playback(should_simulate: bool) -> void:
	is_battling = true
	pause_button.disabled = false
	skip_button.visible = false
	result_dialog.visible = false
	ultimate_panel.close_cast_window()
	log_panel.clear_log()

	if should_simulate:
		# System 層一次性跑完整場戰鬥模擬,結果寫入 battle.battle_log
		battle.start()
	else:
		# 不重新模擬,只是把畫面(站位/HP)歸回開戰當下,再重播同一份 battle_log——
		# 保證每次重播的招式、扣血量完全相同。
		battle.reset_for_replay()
		_setup_battlefield()

	# 場景層依序重播戰報,只負責動畫與畫面呈現
	await _play_battle_log()

	# 播放期間如果場景被切走(節點離開樹但還沒釋放),就不要再碰任何 UI,
	# 直接放棄剩下的收尾流程。
	if not is_inside_tree():
		return

	is_battling = false
	pause_button.disabled = true
	pause_button.text = "暫停"
	_announce_result()
	if should_simulate:
		BattleReward.grant_victory_exp(battle)
		_record_battle_report()


## 把這場戰鬥記錄進全域戰報列表(BattleReportStore),讓玩家之後能在戰報列表回顧。
## 只有「新模擬的一場」會呼叫到這裡——_run_battle_playback() 只在 should_simulate=true
## (剛跑完 battle.start() 的那次)呼叫,_run_battle_realtime() 整場跑完後呼叫一次;
## 戰報播放模式(_enter_playback_mode())跟結果 Dialog 的「重播」按鈕都是重播同一份
## 既有戰報(should_simulate=false),不會、也不該再記一次,否則戰報列表會出現重複項目。
func _record_battle_report() -> void:
	BattleReportStore.add_report(BattleReport.new(title_label.text, battle))


## 即時戰鬥模式(GameEnums.BattleMode.REALTIME):跟 _run_battle_playback() 共用
## System 層的判定/傷害邏輯(Battle.round_progress() 等完全相同),差別只在這裡逐回合
## 呼叫 Battle.step_round() 推進,而不是一次跑完整場。戰鬥照樣自動連續播放、不會逐回合
## 暫停詢問——奧義面板(ultimate_panel)從頭到尾一直開著,玩家隨時想放就直接按,按下去
## 只是把這次施放排進佇列、下一回合開始才生效(見 _on_ultimate_selected()),不打斷
## 戰鬥播放的節奏。目前只有玩家自己這一側(battle.self_ultimates)能手動施放,
## 敵方不會使用奧義。
func _run_battle_realtime() -> void:
	_realtime_active = true
	is_battling = true
	pause_button.disabled = false
	skip_button.visible = true
	result_dialog.visible = false
	log_panel.clear_log()

	ultimate_panel.setup(battle.self_ultimates)
	if not ultimate_panel.ultimate_selected.is_connected(_on_ultimate_selected):
		ultimate_panel.ultimate_selected.connect(_on_ultimate_selected)
	ultimate_panel.open_cast_window()
	_refresh_ultimate_buttons()

	_played_log_index = 0
	battle.start_realtime()
	await _play_new_events()

	var has_more_rounds := true
	while has_more_rounds:
		# is_battling 額外檢查:玩家按了「快速跳過」時,_on_skip_pressed() 會同步跑完
		# 剩餘回合、記錄戰報、彈出結果 Dialog,並把 is_battling 設回 false——這個協程
		# 從 await 恢復執行後如果沒攔住,會拿舊的 has_more_rounds 繼續跑一輪,重複呼叫
		# _announce_result()/_record_battle_report()。
		if not is_inside_tree() or not is_battling:
			_stop_realtime()
			return

		has_more_rounds = battle.step_round()
		await _play_new_events()

		if not is_inside_tree() or not is_battling:
			_stop_realtime()
			return

		# 這回合可能有奧義生效(HP 回復等)或用量被消耗,回合播完就刷新一次按鈕狀態,
		# 不需要額外暫停等玩家確認。
		_refresh_ultimate_buttons()

	ultimate_panel.close_cast_window()

	is_battling = false
	pause_button.disabled = true
	pause_button.text = "暫停"
	skip_button.visible = false
	_announce_result()
	BattleReward.grant_victory_exp(battle)
	_record_battle_report()
	_stop_realtime()


## 這個協程(_run_battle_realtime())真正結束時的統一出口(不管是正常播完、還是被
## 快速跳過中途攔下),發出 realtime_stopped 讓等在旁邊的重播按鈕
## (_on_dialog_replay_pressed())知道可以安全重置戰場了。
func _stop_realtime() -> void:
	_realtime_active = false
	realtime_stopped.emit()


## 玩家在奧義面板點選一個奧義:面板全程開著,呼叫當下主迴圈(_run_battle_realtime())
## 可能正在 await _play_new_events() 播放某一回合的動畫,這裡不要跟著搶播——直接呼叫
## System 層排隊就結束(cast_ultimate() 只是把效果排進下一回合,不涉及畫面播放),
## 下一回合生效時 UltimateResolveEvent 會留給主迴圈下一輪 _play_new_events() 自然播到,
## 不會遺漏也不會被搶播兩次。施放者固定用玩家這一側目前存活的隊長(呼應 LEADER 技能的
## 慣例,見 Spec.md「大將之風」),找不到(隊長已陣亡)就不給放。
func _on_ultimate_selected(ultimate: Ultimate) -> void:
	var caster := _ultimate_caster()
	if caster == null:
		return
	if not UltimateStore.can_use(ultimate):
		return
	if not battle.cast_ultimate(caster, ultimate):
		return
	UltimateStore.consume(ultimate)
	_refresh_ultimate_buttons()


func _ultimate_caster() -> BattleCharacter:
	for battle_character in battle.self_characteres:
		if battle_character.is_leader and not battle_character.is_disabled:
			return battle_character
	return null


func _refresh_ultimate_buttons() -> void:
	for ultimate in battle.self_ultimates:
		var can_cast := battle.can_cast_ultimate(ultimate) and UltimateStore.can_use(ultimate)
		ultimate_panel.refresh_button(ultimate, can_cast, UltimateStore.uses_remaining(ultimate))


## 快速跳過(只有即時戰鬥模式會顯示這顆按鈕,見 skip_button.visible 的切換):不想看完
## 剩下的即時戰鬥時,直接把剩餘回合一次模擬完(不播放動畫,battle.step_round() 本身是
## 同步、不吃 await 的,一個迴圈瞬間跑完),照樣記錄戰報,接著跟正常打完一樣彈出結果
## Dialog(而不是直接離開場景)——玩家仍要自己按 Dialog 的「返回」/「重播」,只是省下
## 中間動畫。_run_battle_realtime() 那個協程可能還卡在某個 await(動畫/計時器)沒有真正
## 結束,但這裡會把 is_battling 設回 false,它下次恢復執行時看到 is_battling 已經不是
## 自己開始時的狀態,配合下方 is_inside_tree() 之外的收尾判斷,不會跟這裡重複跑完戰鬥
## 或重複記錄戰報。
func _on_skip_pressed() -> void:
	if battle_mode != GameEnums.BattleMode.REALTIME or not is_battling:
		return
	while battle.step_round():
		pass
	_played_log_index = battle.battle_log.size()
	ultimate_panel.close_cast_window()
	is_battling = false
	pause_button.disabled = true
	pause_button.text = "暫停"
	skip_button.visible = false
	_announce_result()
	BattleReward.grant_victory_exp(battle)
	_record_battle_report()


## 暫停/繼續:直接切 SceneTree.paused,配合 _safe_wait()/wait_for_animation() 都改成
## process_always=false,讓整場重播(移動補間/攻擊動畫/事件間隔)跟著一起凍結,
## 再按一次原地繼續播放,不需要另外維護播放進度狀態。PauseButton 自己是
## PROCESS_MODE_ALWAYS,暫停時仍然點得到。
func _on_pause_pressed() -> void:
	get_tree().paused = not get_tree().paused
	pause_button.text = "繼續" if get_tree().paused else "暫停"


## 保險:場景以任何方式離開樹(返回上一頁、播放中被切走)都要確保把全域的
## SceneTree.paused 還原成 false,否則暫停狀態會帶到下一個場景,把整個遊戲卡住。
func _exit_tree() -> void:
	get_tree().paused = false


## 10 回合結算:總大將(隊長)死活決定勝負,雙方隊長都撐過 10 回合直接判平手,不比較 HP。
## 直接讀 battle.battle_end_event(型別化,戰鬥跑完後一定有值),不用
## battle.self_total_hp/enemy_total_hp 現算——戰報播放前會呼叫 reset_for_replay() 把
## HP 還原成開戰時的滿血,那兩個 getter 讀到的會是還原後的數字,不是戰鬥結束時的數字。
## 播放已經跑到最後一筆事件、畫面自然停在戰鬥最後一幀,這裡只需要疊一個結果 Dialog
## 上去,不用額外處理「凍結畫面」。
func _announce_result() -> void:
	var end_event := battle.battle_end_event
	var self_total := end_event.self_total
	var enemy_total := end_event.enemy_total
	var result_text: String
	var result_color: Color

	match end_event.result:
		GameEnums.BattleResultType.SELF_WIN:
			result_text = "勝利！"
			result_color = WIN_COLOR
			_log("[color=yellow][b]我方擊敗敵方總大將，我方勝利！(剩餘 HP %d : %d)[/b][/color]" % [self_total, enemy_total])
		GameEnums.BattleResultType.ENEMY_WIN:
			result_text = "戰敗！"
			result_color = LOSE_COLOR
			_log("[color=red][b]我方總大將陣亡，我方戰敗！(剩餘 HP %d : %d)[/b][/color]" % [self_total, enemy_total])
		_:
			result_text = "平手"
			result_color = DRAW_COLOR
			_log("雙方總大將皆存活至第 10 回合，平手。(剩餘 HP %d : %d)" % [self_total, enemy_total])

	result_label.text = result_text
	result_label.add_theme_color_override("font_color", result_color)
	result_detail_label.text = "我方剩餘 HP %d　　敵方剩餘 HP %d" % [self_total, enemy_total]
	result_dialog.visible = true


## 一般情況直接照原路退回上一頁;但如果這場戰鬥是 AskBattle 選「否」進來、呼叫端有
## 指定 on_result callback(例如城門守衛戰鬥後要依勝負秀不同台詞,見
## BattleReportStore.pending_battle_result_callback 的註解),改成呼叫它、由它決定
## 接下來去哪個場景——讀到就立刻清空,不會遺留到下一場沒有指定 callback 的一般戰鬥。
func _on_back_pressed() -> void:
	if BattleReportStore.pending_battle_result_callback.is_valid():
		var callback := BattleReportStore.pending_battle_result_callback
		BattleReportStore.pending_battle_result_callback = Callable()
		callback.call(battle.battle_end_event.result)
		return
	NavigationStore.go_back()


# =========================================================
# 依序重播 System 層產生的結構化戰報(battle.battle_log)
#
# 連續出現的可併發事件(BATCHABLE_EVENT_TYPES:move/daze,沒有傷害計算、也不用播
# 攻擊/技能動畫)會被抓成一批(最多 EVENT_BATCH_SIZE 個)同時播放,加快演示速度;
# attack/skill 事件則跟緊接在後面的閃避/受傷反應事件合併同時播放(不分先後拍);
# 其餘事件維持逐筆播放。
# =========================================================
## AUTO 模式用:battle 已經一次跑完整場模擬,從頭到尾整份播放。
func _play_battle_log() -> void:
	await _play_events_range(0, battle.battle_log.size())


## 即時戰鬥模式用:battle_log 隨著 Battle.step_round()/cast_ultimate() 逐步增長,
## 只播放上次播放到的位置(_played_log_index)之後新增的那一段,播完更新索引,
## 不會每次都從頭重播已經看過的事件。
func _play_new_events() -> void:
	var to_index := battle.battle_log.size()
	await _play_events_range(_played_log_index, to_index)
	_played_log_index = to_index


func _play_events_range(from_index: int, to_index: int) -> void:
	var i := from_index

	while i < to_index:
		# 播放期間場景可能被切走(例如中途按「返回」),節點會離開場景樹但
		# 尚未被釋放,協程恢復執行時若繼續呼叫 get_tree() 會拿到 null 而炸掉,
		# 所以每輪都先確認自己還在樹上,不在就直接放棄剩餘播放。
		if not is_inside_tree():
			return

		var event: BattleEvent = battle.battle_log[i]

		if event.event_type in BATCHABLE_EVENT_TYPES:
			var batch: Array[BattleEvent] = [event]
			i += 1
			while i < to_index and battle.battle_log[i].event_type in BATCHABLE_EVENT_TYPES and batch.size() < EVENT_BATCH_SIZE:
				batch.append(battle.battle_log[i])
				i += 1
			await _play_event_batch(batch)
			await _safe_wait(MOVE_STEP_DELAY)
			continue

		# B. 守護觸發:guard 事件後面一定緊接著 attack/skill(見
		# CombatResolver.resolve_guard() 的呼叫順序),整組(飛身頂替 + 攻擊 + 反應 +
		# 歸位)當一個單位播放。
		if event.event_type == GameEnums.BattleEventType.GUARD and i + 1 < to_index and battle.battle_log[i + 1].event_type in [GameEnums.BattleEventType.ATTACK, GameEnums.BattleEventType.SKILL]:
			var guarded_action_event: BattleEvent = battle.battle_log[i + 1]
			var guarded_reaction_events: Array[BattleEvent] = []
			var k := i + 2
			while k < to_index and battle.battle_log[k].event_type in REACTION_EVENT_TYPES:
				guarded_reaction_events.append(battle.battle_log[k])
				k += 1
			await _play_guarded_action(event as GuardEvent, guarded_action_event, guarded_reaction_events)
			i = k
			await _safe_wait(STEP_DELAY)
			continue

		# 奧義生效若波及全體(例如龍捲風對敵方全體造成傷害),緊接著的反應事件
		# 比照 AoE 技能收進同一批一起套用,不要像沒有這段前瞻邏輯時那樣退化成
		# 逐筆播放、一個人一個人受傷害。
		if event.event_type == GameEnums.BattleEventType.ULTIMATE_RESOLVE and i + 1 < to_index and battle.battle_log[i + 1].event_type in REACTION_EVENT_TYPES:
			var ultimate_reaction_events: Array[BattleEvent] = []
			var u := i + 1
			while u < to_index and battle.battle_log[u].event_type in REACTION_EVENT_TYPES:
				ultimate_reaction_events.append(battle.battle_log[u])
				u += 1
			_apply_ultimate_resolve(event as UltimateResolveEvent)
			for ultimate_reaction_event in ultimate_reaction_events:
				_apply_reaction(ultimate_reaction_event)
			i = u
			await _safe_wait(STEP_DELAY)
			continue

		if (event.event_type == GameEnums.BattleEventType.ATTACK or event.event_type == GameEnums.BattleEventType.SKILL) and i + 1 < to_index and battle.battle_log[i + 1].event_type in REACTION_EVENT_TYPES:
			# 範圍技能可能一次波及多個目標,緊接著的反應事件(dodge/damage)不保證只有一筆,
			# 把連續出現的都收進同一批,一起套用。
			var reaction_events: Array[BattleEvent] = []
			var j := i + 1
			while j < to_index and battle.battle_log[j].event_type in REACTION_EVENT_TYPES:
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
func _play_event_batch(batch: Array[BattleEvent]) -> void:
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
	# process_always=false:讓這個計時器跟著 SceneTree.paused 一起暫停,配合暫停按鈕
	# (_on_pause_pressed())凍結整場重播,而不是暫停時間到了還繼續跑下一筆事件。
	await get_tree().create_timer(seconds, false).timeout


func _play_tracked_event(event: BattleEvent) -> void:
	match event.event_type:
		GameEnums.BattleEventType.MOVE:
			await _anim_move(event as MoveEvent)
		GameEnums.BattleEventType.DAZE:
			var daze_event := event as DazeEvent
			_roster_for(daze_event.actor).pulse_active(daze_event.actor)
			_log(_hint("%s 猶豫了一下" % daze_event.actor_name, daze_event))
	_pending_batch_actions -= 1


func _play_single_event(event: BattleEvent) -> void:
	match event.event_type:
		GameEnums.BattleEventType.BATTLE_START:
			_log("戰鬥開始")
		GameEnums.BattleEventType.ROUND_START:
			var round_start_event := event as RoundStartEvent
			_log("[b]—— 第 %d 回合 ——[/b]" % round_start_event.round)
			round_label.text = "回合 %d" % round_start_event.round
		GameEnums.BattleEventType.ROUND_END:
			_log("回合結束")
			await _safe_wait_frame()
		GameEnums.BattleEventType.ATTACK:
			await _anim_attack(event as AttackEvent)
		GameEnums.BattleEventType.SKILL:
			await _anim_skill(event as SkillEvent)
		GameEnums.BattleEventType.DODGE, GameEnums.BattleEventType.DAMAGE, GameEnums.BattleEventType.HEAL, GameEnums.BattleEventType.STAT_EFFECT:
			_apply_reaction(event)
		GameEnums.BattleEventType.GUARD:
			# 正常情況下 guard 一定會被 _play_battle_log() 的前瞻邏輯跟緊接著的
			# attack/skill 一起交給 _play_guarded_action() 播放,不會走到這裡;
			# 這個分支只在極端情況(戰報被截斷等)當純文字 fallback。
			var guard_event := event as GuardEvent
			_log(_hint("%s 飛身守護,替 %s 承受這次攻擊！" % [guard_event.actor_name, guard_event.target_name], guard_event))
		GameEnums.BattleEventType.STAT_EFFECT_EXPIRED:
			_apply_stat_effect_expired(event as StatEffectExpiredEvent)
		GameEnums.BattleEventType.DEFEATED:
			_apply_defeated(event as DefeatedEvent)
		GameEnums.BattleEventType.BATTLE_END:
			_log("戰鬥結束(共 %d 回合)，進行結算。" % (event as BattleEndEvent).round)
		GameEnums.BattleEventType.ULTIMATE_RESOLVE:
			_apply_ultimate_resolve(event as UltimateResolveEvent)


## attack/skill 動畫與緊接在後的閃避/受傷反應同時播放,不要分先後拍:
## 攻擊方的揮擊動畫一開始播放,就立刻套用防禦方的反應,兩邊動畫同時進行。
## reaction_events 可能不只一筆——範圍技能一次波及多個目標時,每個目標各自的
## 受擊/閃避反應會同時套用在各自的角色身上。reaction_events 傳空陣列時就是單純播放
## 攻擊/技能動畫本身,_anim_attack()/_anim_skill() 共用這份實作。
func _play_action_with_reaction(action_event: BattleEvent, reaction_events: Array[BattleEvent]) -> void:
	var is_skill := action_event is SkillEvent
	var actor_character: BattleCharacter = (action_event as SkillEvent).actor if is_skill else (action_event as AttackEvent).actor
	var target_character: BattleCharacter = (action_event as SkillEvent).target if is_skill else (action_event as AttackEvent).target

	var actor: BattleUnitVisual = visuals.get(actor_character)
	var target: BattleUnitVisual = visuals.get(target_character)
	if actor == null or target == null:
		return

	if is_skill:
		var skill_event := action_event as SkillEvent
		# 中性措辭「對 X 使用技能」,不寫死「攻擊」——C. 治癒/D. 大將之風這類技能
		# 的 target 是施法者自己或全隊,講「攻擊」會語意不通。
		_log(_hint("%s 對 %s 使用技能「%s」！" % [skill_event.actor_name, skill_event.target_name, skill_event.skill_name], skill_event))
		_roster_for(actor_character).pulse_skill(actor_character, skill_event.skill_name)
		actor.play_skill_light()
	else:
		var attack_event := action_event as AttackEvent
		_log(_hint("%s 攻擊 %s！" % [attack_event.actor_name, attack_event.target_name], attack_event))
		_roster_for(actor_character).pulse_active(actor_character)

	var anim := actor.play_attack_towards(target.grid_pos)

	# 不 await,讓反應動畫跟攻擊動畫同時播放
	for reaction_event in reaction_events:
		_apply_reaction(reaction_event)

	await actor.wait_for_animation(anim)
	actor.idle_towards(target.grid_pos)


func _apply_reaction(event: BattleEvent) -> void:
	match event.event_type:
		GameEnums.BattleEventType.DODGE:
			var dodge_event := event as DodgeEvent
			_log(_hint("%s 閃避了 %s 的攻擊" % [dodge_event.target_name, dodge_event.actor_name], dodge_event))
			var dodge_visual: BattleUnitVisual = visuals.get(dodge_event.target)
			if dodge_visual != null:
				dodge_visual.play_dodge_reaction()
		GameEnums.BattleEventType.DAMAGE:
			var damage_event := event as DamageEvent
			var crit_text := "[color=red][b]（暴擊！）[/b][/color]" if damage_event.is_critical else ""
			_log(_hint("%s 受到 %d 點傷害%s" % [damage_event.target_name, damage_event.damage_points, crit_text], damage_event))
			var hit_visual: BattleUnitVisual = visuals.get(damage_event.target)
			if hit_visual != null:
				hit_visual.play_hit_reaction()
				hit_visual.show_damage_number(damage_event.damage_points, damage_event.is_critical)
				_roster_for(damage_event.target).update_hp(damage_event.target, damage_event.remaining_hp)
		GameEnums.BattleEventType.HEAL:
			var heal_event := event as HealEvent
			_log(_hint("%s 恢復 %d 點 HP" % [heal_event.target_name, heal_event.heal_points], heal_event))
			var heal_visual: BattleUnitVisual = visuals.get(heal_event.target)
			if heal_visual != null:
				heal_visual.show_heal_number(heal_event.heal_points)
				_roster_for(heal_event.target).update_hp(heal_event.target, heal_event.remaining_hp)
		GameEnums.BattleEventType.STAT_EFFECT:
			var stat_event := event as StatEffectEvent
			_log(_hint("%s %s(%s)" % [
				stat_event.target_name,
				("獲得增益" if stat_event.is_buff else "受到減益"),
				GameEnums.format_potential_type_list(stat_event.potential_types),
			], stat_event))
			_roster_for(stat_event.target).add_status_arrows(stat_event.target, stat_event.potential_types, stat_event.is_buff)
			# 整場戰鬥其實在 Battle.start() 就瞬間模擬完了,BattleCharacter 的「真實」素質修正
			# 早就是模擬結束當下的最終結果——這裡重播到這個事件時,同步更新一份「顯示用」
			# 修正清單(見 BattleCharacter._replay_stat_modifiers),角色面板雷達圖才能跟上
			# 重播進度顯示正確數值,而不是整場戰鬥都定格在結局。
			for potential_type in stat_event.potential_types:
				stat_event.target.apply_replay_stat_effect(potential_type, stat_event.multiplier, stat_event.rounds)
			var stat_visual: BattleUnitVisual = visuals.get(stat_event.target)
			if stat_visual != null:
				stat_visual.play_stat_effect_spin()


## 移動:System 層已經算好整趟路徑(event.path,可能為了繞路而轉彎),
## 這裡把棋盤座標換算成像素座標,交給 BattleUnitVisual 連續播放,
## 只記一次「靠近/遠離」訊息,避免多格移動時畫面逐格停頓、洗版同樣的訊息。
func _anim_move(event: MoveEvent) -> void:
	var actor: BattleUnitVisual = visuals.get(event.actor)
	if actor == null:
		return

	_roster_for(event.actor).pulse_active(event.actor)

	if event.away:
		_log(_hint("%s 遠離 %s" % [event.actor_name, event.target_name], event))
	else:
		_log(_hint("%s 向 %s 靠近" % [event.actor_name, event.target_name], event))

	var path_pixel: Array = []
	for p in event.path:
		path_pixel.append(board.grid_to_pixel(p))

	await actor.move_along(event.path, path_pixel, MOVE_TIME)


## 沒有緊接反應事件時的備用路徑(理論上 attack/skill 一定緊跟著 dodge/damage,
## 這兩個函式只在極端情況——例如截斷戰報做除錯——才會被單獨呼叫到),
## 跟有反應事件的情況共用同一份播放邏輯(_play_action_with_reaction),
## 只是傳空的 reaction_events。
func _anim_attack(event: AttackEvent) -> void:
	await _play_action_with_reaction(event, [])


func _anim_skill(event: SkillEvent) -> void:
	await _play_action_with_reaction(event, [])


func _apply_defeated(event: DefeatedEvent) -> void:
	var visual: BattleUnitVisual = visuals.get(event.party)
	if visual == null:
		return

	_log("[color=gray]%s 戰敗[/color]" % event.party_name)

	visual.apply_defeated()
	_roster_for(event.party).mark_defeated(event.party)


## 奧義生效:延遲回合到了(Battle._round_start() 呼叫 Ultimate.resolve()),數值效果
## (回血/傷害等)真正套用的那一刻。resolve_line 不是「即將發生」的預告,而是效果本身
## 發生當下的天象描述(例如「詭異龍捲風攻擊敵人」)——施放的當下不會另外顯示東西,
## 只有這裡(生效當下)才在戰場正中央浮出台詞(不是 Skill 那種「在角色頭像旁邊喊招式
## 名稱」的表現,見 _show_ultimate_banner())。戰報文字一樣顯示這句台詞,判定細節
## 只放在滑鼠懸停(_hint())裡,目前是方便除錯用,正式版拿掉詳細戰報後不影響玩家看到
## 的台詞本身。
func _apply_ultimate_resolve(event: UltimateResolveEvent) -> void:
	_log(_hint("[color=cyan][b]%s[/b][/color]" % event.flavor_text, event))
	_show_ultimate_banner(event.flavor_text)


## 在戰場正中央浮出一行大字,不 await——淡入 → 停留 → 淡出後自動釋放,不擋播放節奏。
## 位置依 board 目前的縮放狀態(見 _apply_board_layout())即時算出視覺中心;banner
## 本身掛在場景根節點下(不隨 board/units_layer 縮放),字體大小固定可讀,不會因為
## 戰場縮小/放大而跟著變形。
func _show_ultimate_banner(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", ULTIMATE_BANNER_FONT_SIZE)
	label.add_theme_color_override("font_color", ULTIMATE_BANNER_COLOR)
	label.add_theme_color_override("font_outline_color", ULTIMATE_BANNER_OUTLINE_COLOR)
	label.add_theme_constant_override("outline_size", ULTIMATE_BANNER_OUTLINE_SIZE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 10
	label.modulate.a = 0.0
	add_child(label)

	# 等一影格讓 Label 依內容算出實際尺寸,才能正確置中。
	await get_tree().process_frame
	if not is_instance_valid(label):
		return

	label.size = label.get_combined_minimum_size()
	var board_center := BOARD_PIVOT + Vector2(BOARD_BASE_WIDTH, BOARD_BASE_HEIGHT) * 0.5 * board.scale.x
	label.position = board_center - label.size * 0.5

	var tw := label.create_tween()
	tw.tween_property(label, "modulate:a", 1.0, ULTIMATE_BANNER_FADE_TIME)
	tw.tween_interval(ULTIMATE_BANNER_HOLD_TIME)
	tw.tween_property(label, "modulate:a", 0.0, ULTIMATE_BANNER_FADE_TIME)
	tw.tween_callback(label.queue_free)


## B. 守護觸發的完整演出:守護者先飛身到受擊者面前(面向攻擊方)、喊出招式名稱,
## 站定位後才播放緊接著的 attack/skill + 反應事件(此時 System 層已經把該次攻擊的
## target 換成守護者本人,動畫自然會對準守護者),最後守護者再歸位。理論上 guard
## 一定緊跟著 attack/skill(見 CombatResolver.resolve_guard() 的呼叫順序),
## 這裡的 fallback 只在極端情況(例如視覺節點缺失)才會退化成純文字。
func _play_guarded_action(guard_event: GuardEvent, action_event: BattleEvent, reaction_events: Array[BattleEvent]) -> void:
	var guardian: BattleUnitVisual = visuals.get(guard_event.actor)
	var original_target: BattleUnitVisual = visuals.get(guard_event.target)
	var attacker: BattleUnitVisual = visuals.get(guard_event.attacker)
	if guardian == null or original_target == null or attacker == null:
		_log(_hint("%s 飛身守護,替 %s 承受這次攻擊！" % [guard_event.actor_name, guard_event.target_name], guard_event))
		await _play_action_with_reaction(action_event, reaction_events)
		return

	_log(_hint("%s 使用技能「%s」！" % [guard_event.actor_name, guard_event.skill_name], guard_event))
	_roster_for(guard_event.actor).pulse_skill(guard_event.actor, guard_event.skill_name)

	await guardian.play_guard_dash_in(original_target.position, attacker.position)
	await _play_action_with_reaction(action_event, reaction_events)
	await guardian.play_guard_dash_out()


## D. 大將之風/E. 降咒 這類限時增益/減益到期:拿掉頭像旁對應的箭頭。
func _apply_stat_effect_expired(event: StatEffectExpiredEvent) -> void:
	_log("%s 的%s效果解除(%s)" % [
		event.target_name,
		("增益" if event.is_buff else "減益"),
		GameEnums.format_potential_type_list(event.potential_types),
	])
	_roster_for(event.target).remove_status_arrows(event.target, event.potential_types, event.is_buff)
	for potential_type in event.potential_types:
		event.target.expire_replay_stat_effect(potential_type, event.is_buff)


# =========================================================
# 戰鬥紀錄
# =========================================================
func _log(msg: String) -> void:
	log_panel.log_msg(msg)


## 事件如果帶了 System 層組好的 detail(判定/骰值/公式全文,見 CombatResolver 的
## judge_dodge()/judge_crit() 等),用 RichTextLabel 內建的 [hint=...] 標籤包起來,
## 滑鼠移到這行文字上就會彈出完整說明。log_panel 本身要設成 process_mode =
## PROCESS_MODE_ALWAYS(見 battle.tscn)才能在暫停時也正常觸發——暫停只是凍結播放,
## 不是要連戰報都看不了。detail 字串本身規定不能含方括號(見 System 端註解),
## 這裡不用再處理跳脫。
func _hint(text: String, event: BattleEvent) -> String:
	if event.detail == "":
		return text
	return "[hint=%s]%s[/hint]" % [event.detail, text]
