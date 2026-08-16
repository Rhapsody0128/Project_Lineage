class_name Battle
extends RefCounted

## 戰場格子大小,參考信喵之野望的縱向戰場:玩家在下方、敵方在上方,
## 6 路縱隊往中間推進交戰。左右(GRID_COLS)12 格、上下(GRID_ROWS)6 格。
const GRID_COLS := 12
const GRID_ROWS := 6

## 固定跑 10 回合結算。總大將沿用現有隊長機制(Party.leader/BattleCharacter.is_leader):
## 隊長陣亡立即分出勝負(見 is_decided);雙方隊長都撐過 10 回合則直接判平手,
## 不比較 HP(見 result)。
const TOTAL_ROUND := 10

var self_characteres: Array[BattleCharacter]
var enemy_characteres: Array[BattleCharacter]

## 雙方可施放的奧義(見 System/ultimate/),即時戰鬥模式(start_realtime())才會用到,
## 從 Party.ultimates 複製一份——奧義本身是無狀態資料,施放次數限制另外用
## _ultimate_use_counts(依 Ultimate.id 計數)追蹤,不會共用/污染到 Party 上的原始清單。
var self_ultimates: Array[Ultimate] = []
var enemy_ultimates: Array[Ultimate] = []

var _round: int = 0

## 結構化戰報,依序記錄戰鬥中發生的每一個事件,供外部(UI/場景)重播使用
var battle_log: Array[BattleEvent] = []

func _init(self_party: Party, enemy_party: Party) -> void:
	self_characteres = _attach_battle_characteres(false, self_party)
	enemy_characteres = _attach_battle_characteres(true, enemy_party)
	_deploy_side(self_characteres, self_party, false)
	_deploy_side(enemy_characteres, enemy_party, true)
	self_ultimates = self_party.ultimates.duplicate()
	enemy_ultimates = enemy_party.ultimates.duplicate()
	_capture_start_state()

## 小隊裡的每個角色,在戰場上各自佔一格獨立作戰。不再開戰前強制回滿血——Character.hp 是
## 跨多場戰鬥持續累積的殘血(例如 PartyEdit 編成的角色),只能靠大地圖時間流逝按
## Character.HP_REGEN_PER_DAY 自然回復(見 Scenes/Map/map.gd 的 _process()),重傷後立刻
## 再戰一場會直接帶著殘血上場。唯一例外是已經 0 血(戰敗)的角色:不用等時間流逝
## 自然回血,開戰當下直接把殘血墊到 1,以極限殘血狀態硬撐著再戰一場,而不是連場
## 上都站不了。
func _attach_battle_characteres(is_enemy: bool, party: Party) -> Array[BattleCharacter]:
	var battle_characteres: Array[BattleCharacter] = []
	for character in party.characteres:
		if character.is_disabled:
			character.hp = 1
		var is_leader := character == party.leader
		battle_characteres.append(BattleCharacter.new(character, self, is_enemy, is_leader))
	return battle_characteres

## 初始佈陣:Party.battle_cost_positions 有記錄站位的角色(PartyEdit 編成畫面
## 擺過)直接照那個位置站(座標系跟這裡的自身區同一套,見 PartyEditGrid 開頭
## 註解,不需要換算);沒有記錄站位的角色(例如隨機生成的敵方小隊)沿用舊版
## 「靠邊置中排縱隊」規則。兩種角色可以同時出現在同一個 Battle 裡
## (玩家小隊 vs 隨機敵方小隊就是典型情況),各自獨立處理、互不影響。
func _deploy_side(battle_characteres: Array[BattleCharacter], party: Party, is_enemy: bool) -> void:
	var unplaced: Array[BattleCharacter] = []
	for battle_character in battle_characteres:
		if party.has_battle_position(battle_character.character):
			battle_character.grid_pos = party.get_battle_position(battle_character.character)
		else:
			unplaced.append(battle_character)

	_deploy_column_formation(unplaced, is_enemy)

## 縱隊靠邊排開,一欄站滿 GRID_ROWS 人就往中間多開一欄(自己這邊從 x=0 往中間開,
## 敵方從 x=GRID_COLS-1 往中間開),不會像單欄版本那樣人數一多(例如小隊上限
## 12 人)就超出 GRID_ROWS=6 的棋盤高度、把座標算到棋盤外面。只有「最後一欄」
## 可能沒站滿,沿用舊規則置中;前面站滿的每一欄都是滿的,不需要置中。
func _deploy_column_formation(unplaced: Array[BattleCharacter], is_enemy: bool) -> void:
	if unplaced.is_empty():
		return

	var edge_x := 0 if not is_enemy else GRID_COLS - 1
	var x_step := 1 if not is_enemy else -1
	var full_columns := unplaced.size() / GRID_ROWS

	for i in range(unplaced.size()):
		var column := i / GRID_ROWS
		var row_in_column := i % GRID_ROWS
		var rows_in_column := GRID_ROWS if column < full_columns else unplaced.size() % GRID_ROWS
		var row_offset := (GRID_ROWS - rows_in_column) / 2
		var x := edge_x + column * x_step
		unplaced[i].grid_pos = Vector2i(x, row_offset + row_in_column)

## 該格子是否已有「其他」存活角色佔據(排除 exclude 自己)。
## 已戰敗的角色不算佔用 —— 移動途中可以直接穿過己方存活角色,
## 最終落腳點只需要避開所有「存活中」的角色(不分陣營),戰敗角色的位置可以站上去。
func is_occupied_excluding(pos: Vector2i, exclude: BattleCharacter) -> bool:
	for battle_character in self_characteres:
		if battle_character != exclude and not battle_character.is_disabled and battle_character.grid_pos == pos:
			return true
	for battle_character in enemy_characteres:
		if battle_character != exclude and not battle_character.is_disabled and battle_character.grid_pos == pos:
			return true
	return false

## 行動順序
var action_order: Array[BattleCharacter]:
	get:
		var battle_characteres: Array[BattleCharacter] = []
		for battle_character in self_characteres:
			if not battle_character.is_disabled:
				battle_characteres.append(battle_character)
		for battle_character in enemy_characteres:
			if not battle_character.is_disabled:
				battle_characteres.append(battle_character)
		battle_characteres.sort_custom(func(a: BattleCharacter, b: BattleCharacter) -> bool: return a.action_speed > b.action_speed)
		return battle_characteres

## 開始戰鬥,一次性跑完整場模擬並寫入 battle_log(戰報模式,GameEnums.BattleMode.AUTO)
func start() -> void:
	_init_battle()
	while _round < TOTAL_ROUND and not is_decided:
		_round_start()
		round_progress()
		_round_end()
	_conclude_battle()

## 是否已經開始即時戰鬥(start_realtime() 呼叫過)/是否已經結束(跑滿 TOTAL_ROUND 或
## 分出勝負)。AUTO 模式(start())不使用這兩個旗標。
var is_realtime_started: bool = false
var is_over: bool = false

## 即時戰鬥模式(GameEnums.BattleMode.REALTIME)進場:只記開戰事件,不往下跑,
## 之後由呼叫端逐回合呼叫 step_round() 推進——回合之間才有空檔讓玩家決定要不要
## 呼叫 cast_ultimate() 施放奧義。跟 start() 共用 round_progress()/_round_start()/
## _round_end() 這套核心迴圈,行動決策/傷害判定等規則完全不因模式而異,差別只在
## 這裡是外部一次跑一回合,不是內部一次跑完整場。
func start_realtime() -> void:
	_init_battle()
	is_realtime_started = true

## 跑完剛好一個回合;回傳 false 代表戰鬥已經結束(跑滿 TOTAL_ROUND 或分出勝負),
## 呼叫端不用再呼叫。尚未呼叫 start_realtime() 或戰鬥已結束時直接回傳 false。
func step_round() -> bool:
	if not is_realtime_started or is_over:
		return false

	_round_start()
	round_progress()
	_round_end()

	if _round >= TOTAL_ROUND or is_decided:
		_conclude_battle()
		is_over = true
		return false
	return true

func _init_battle() -> void:
	log_event(BattleStartEvent.new())

func _round_start() -> void:
	log_event(RoundStartEvent.new(_round + 1))
	_resolve_pending_ultimate_effects(_round + 1)

## 回合進行:全滅的一方沒有敵人可打,action() 內部 search_enemy() 找不到目標會自動
## 提前 return,不需要另外判斷戰鬥是否已經分出勝負;但只要有一方隊長陣亡
## (is_decided 變 true),就要當場中斷本回合剩餘角色的行動,不等回合跑完。
##
## 每個角色行動完,立刻結算「自己」的限時素質修正(buff/debuff)——不是等整個大回合
## 跑完才一次結算所有人。這樣「持續 3 回合」對每個角色來說,實際上是「接下來自己
## 的 3 次行動機會」,不會因為在同一個大回合裡站位/行動順序比較後面,就被大回合結束
## 的那一下 tick 提早打折扣。
func round_progress() -> void:
	for battle_character in action_order:
		if not battle_character.is_disabled:
			battle_character.action()
			_tick_status_effects(battle_character)
		if is_decided:
			break

func _round_end() -> void:
	log_event(RoundEndEvent.new(_round + 1))
	_round += 1

## 單一角色的限時素質修正(見 BattleCharacter.add_stat_modifier())各自倒數 1 回合,到期就
## 移除並記一筆 stat_effect_expired 事件,讓頭像旁的箭頭指示跟著消失。永久修正
## (被動技能)不受影響。同一次可能有多筆修正同時到期,依增益/減益分兩組各記一筆事件,
## 不逐筆記,才會跟套用時的分組方式一致,戰報/頭像箭頭不會被拆得太零碎。
func _tick_status_effects(battle_character: BattleCharacter) -> void:
	var expired := battle_character.tick_status_effects()
	if expired.is_empty():
		return

	var buff_types: Array[int] = []
	var debuff_types: Array[int] = []
	for m in expired:
		if m.multiplier > 0.0:
			buff_types.append(m.potential_type)
		else:
			debuff_types.append(m.potential_type)

	if not buff_types.is_empty():
		log_event(StatEffectExpiredEvent.new(battle_character, buff_types, true))
	if not debuff_types.is_empty():
		log_event(StatEffectExpiredEvent.new(battle_character, debuff_types, false))

## 隊長(總大將)陣亡視為戰鬥分出勝負,立即結束整場戰鬥(不必等到跑滿 TOTAL_ROUND)。
## 找不到隊長(理論上不會發生)時視為不會提前結束。
var is_decided: bool:
	get:
		var self_leader := _find_leader(self_characteres)
		var enemy_leader := _find_leader(enemy_characteres)
		return (self_leader != null and self_leader.is_disabled) or (enemy_leader != null and enemy_leader.is_disabled)

func _find_leader(battle_characteres: Array[BattleCharacter]) -> BattleCharacter:
	for battle_character in battle_characteres:
		if battle_character.is_leader:
			return battle_character
	return null

## 勝負判定:只看雙方總大將(隊長)死活,不比較 HP。跑滿 10 回合時雙方隊長必定都還
## 存活(否則 is_decided 早就提前結束了),此時直接判平手。
var result: GameEnums.BattleResultType:
	get:
		var self_leader := _find_leader(self_characteres)
		var enemy_leader := _find_leader(enemy_characteres)
		var self_dead: bool = self_leader != null and self_leader.is_disabled
		var enemy_dead: bool = enemy_leader != null and enemy_leader.is_disabled
		if enemy_dead and not self_dead:
			return GameEnums.BattleResultType.SELF_WIN
		if self_dead and not enemy_dead:
			return GameEnums.BattleResultType.ENEMY_WIN
		return GameEnums.BattleResultType.DRAW

## 結算時機:跑滿 TOTAL_ROUND 回合,或有一方隊長提前陣亡(is_decided)。
## HP 總量純粹保留給畫面展示用,實際勝負一律看 result。
func _conclude_battle() -> void:
	log_event(BattleEndEvent.new(_round, self_total_hp, enemy_total_hp, result))

# =========================================================
# 奧義(即時戰鬥模式專用,見 System/ultimate/):施放(cast)跟生效(resolve)分成
# 兩個時間點——cast_ultimate() 當下只記錄戰報事件、把效果排進 pending_ultimate_effects
# 佇列,真正的數值效果留到 _round_start() 判斷「輪到這回合了」才呼叫 Ultimate.resolve()
# 套用,對應「這回合施放,下回合才生效」的設計(見 Ultimate.delay_rounds)。
# =========================================================

## 排隊等待生效的奧義效果,每筆 {"resolve_round": int, "caster": BattleCharacter,
## "ultimate": Ultimate}。不用型別化事件類別包這筆資料——這是 Battle 內部排程用的
## 暫存狀態,不是要給外部(UI/戰報)讀的「已發生」紀錄,跟 _start_state 一樣用 Dictionary。
var pending_ultimate_effects: Array[Dictionary] = []

## 每個奧義(依 Ultimate.id)這場戰鬥已經施放過幾次,超過 Ultimate.max_uses_per_battle
## 就不能再放,見 can_cast_ultimate()。
var _ultimate_use_counts: Dictionary = {}

func can_cast_ultimate(ultimate: Ultimate) -> bool:
	if is_over or is_decided:
		return false
	if ultimate.max_uses_per_battle < 0:
		return true
	var uses: int = _ultimate_use_counts.get(ultimate.id, 0)
	return uses < ultimate.max_uses_per_battle

## 這個奧義這場戰鬥還能放幾次,UI(奧義按鈕)顯示用。-1 代表不限次數(Ultimate.
## max_uses_per_battle < 0)。
func ultimate_uses_remaining(ultimate: Ultimate) -> int:
	if ultimate.max_uses_per_battle < 0:
		return -1
	var uses: int = _ultimate_use_counts.get(ultimate.id, 0)
	return maxi(ultimate.max_uses_per_battle - uses, 0)

## 施放一個奧義:caster 只影響效果解讀(例如以誰為中心算範圍),「天降甘霖」這種全隊
## 效果不吃施法者素質。施放當下算好 resolve_round 存進 pending_ultimate_effects,實際
## 效果留給 _round_start() 到時候呼叫。can_cast_ultimate() 為 false 時直接失敗、不計入
## 次數。
##
## resolve_round 算法:即時戰鬥逐回合跑(step_round()),模擬永遠跑在畫面播放前面——
## 玩家點下施放的當下,battle_log 播放到的那一回合(玩家「感覺上」正在看的回合)其實
## 早就模擬完了、_round 已經被 _round_end() 加計為那一回合的編號,不是「即將開始」的
## 編號。所以「下一回合生效」單純是 _round + delay_rounds,不能再疊加一次
## 「+1 代表下一回合」——疊加會多算一輪,變成玩家感覺的「下下回合」才生效。
func cast_ultimate(caster: BattleCharacter, ultimate: Ultimate) -> bool:
	if not can_cast_ultimate(ultimate):
		return false

	_ultimate_use_counts[ultimate.id] = _ultimate_use_counts.get(ultimate.id, 0) + 1
	var resolve_round := _round + ultimate.delay_rounds
	pending_ultimate_effects.append({
		"resolve_round": resolve_round,
		"caster": caster,
		"ultimate": ultimate,
	})
	ultimate.cast(caster, resolve_round)
	return true

## _round_start() 開場呼叫:把排定在這一回合生效的奧義效果全部套用並從佇列移除,
## 順序在 RoundStartEvent 記錄之後、round_progress() 之前——奧義的效果(例如回血)
## 要在角色行動前就反映在 HP 上。
func _resolve_pending_ultimate_effects(round_number: int) -> void:
	for pending in pending_ultimate_effects.duplicate():
		if pending.resolve_round != round_number:
			continue
		var ultimate: Ultimate = pending.ultimate
		var caster: BattleCharacter = pending.caster
		ultimate.resolve(caster)
		pending_ultimate_effects.erase(pending)

## 戰鬥結束事件,戰鬥跑完後一定有值——BattleReport/battle.gd 都改讀這個當唯一結算
## 來源,不要再各自寫一份「掃 battle_log 找 battle_end,找不到就退回現算」的 fallback。
var battle_end_event: BattleEndEvent:
	get:
		for event in battle_log:
			if event is BattleEndEvent:
				return event
		return null

var self_total_hp: int:
	get: return _sum_hp(self_characteres)
var enemy_total_hp: int:
	get: return _sum_hp(enemy_characteres)

func _sum_hp(battle_characteres: Array[BattleCharacter]) -> int:
	var total := 0
	for battle_character in battle_characteres:
		total += battle_character.hp
	return total

## 開戰當下每個角色的 HP/座標快照,供戰報重複播放時還原畫面用——battle_log
## 本身的招式/傷害數字已經是模擬完固定好的,重播不會、也不該重新跑一次 start(),
## 只需要把 HP 條跟站位歸回開戰當下,再依序重播同一份 battle_log。
var _start_state: Dictionary = {} # BattleCharacter -> {hp: int, grid_pos: Vector2i}

func _capture_start_state() -> void:
	for battle_character in self_characteres + enemy_characteres:
		_start_state[battle_character] = {"hp": battle_character.hp, "grid_pos": battle_character.grid_pos}

## 戰報重播用:把所有角色 HP 與棋盤座標還原到開戰當下的狀態
func reset_for_replay() -> void:
	for battle_character: BattleCharacter in _start_state:
		var state: Dictionary = _start_state[battle_character]
		battle_character.character.hp = state.hp
		battle_character.grid_pos = state.grid_pos

## 戰報統計面板用:讀開戰當下的 HP 快照,不受重播/reset_for_replay() 影響——
## 戰報可能已經被玩家看過重播(character.hp 被改到重播進度),統計面板要顯示的「原始血量」
## 一律讀這裡,不能直接讀 battle_character.hp。
func start_hp(battle_character: BattleCharacter) -> int:
	var state: Dictionary = _start_state.get(battle_character, {})
	return state.get("hp", battle_character.hp)

## 記錄一筆結構化戰報事件
func log_event(event: BattleEvent) -> void:
	battle_log.append(event)
