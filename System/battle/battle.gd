class_name Battle
extends RefCounted

## 戰場格子大小,參考信喵之野望的縱向戰場:玩家在下方、敵方在上方,
## 6 路縱隊往中間推進交戰。左右(GRID_COLS)12 格、上下(GRID_ROWS)6 格。
const GRID_COLS := 12
const GRID_ROWS := 6

var self_parties: Array[BattleParty]
var self_party_leader: BattleParty
var enemy_parties: Array[BattleParty]
var enemy_party_leader: BattleParty

var _total_round: int = 60
var _round: int = 0

## 結構化戰報,依序記錄戰鬥中發生的每一個事件,供外部(UI/場景)重播使用
var battle_log: Array[Dictionary] = []

func _init(self_troop: Troop, enemy_troop: Troop) -> void:
	self_parties = _attach_battle_params(false, self_troop.parties)
	self_party_leader = _attach_battle_param(false, self_troop.party_leader)
	enemy_parties = _attach_battle_params(true, enemy_troop.parties)
	enemy_party_leader = _attach_battle_param(true, enemy_troop.party_leader)
	_deploy_initial_positions()

func _attach_battle_param(is_enemy: bool, party: Party) -> BattleParty:
	return BattleParty.new(party, self, is_enemy)

func _attach_battle_params(is_enemy: bool, parties: Array[Party]) -> Array[BattleParty]:
	var battle_parties: Array[BattleParty] = []
	for party in parties:
		battle_parties.append(BattleParty.new(party, self, is_enemy))
	return battle_parties

## 初始佈陣:我方沿最左列、敵方沿最右列,各自置中排成一列縱隊的隊頭
func _deploy_initial_positions() -> void:
	var self_start_y := (GRID_ROWS - self_parties.size()) / 2
	for i in range(self_parties.size()):
		self_parties[i].grid_pos = Vector2i(0, self_start_y + i)

	var enemy_start_y := (GRID_ROWS - enemy_parties.size()) / 2
	for i in range(enemy_parties.size()):
		enemy_parties[i].grid_pos = Vector2i(GRID_COLS - 1, enemy_start_y + i)

## 該格子是否已有「其他」存活隊伍佔據(排除 exclude 自己)。
## 已陣亡(全軍覆沒)的隊伍不算佔用 —— 移動途中可以直接穿過己方存活角色,
## 最終落腳點只需要避開所有「存活中」的角色(不分陣營),陣亡角色的位置可以站上去。
func is_occupied_excluding(pos: Vector2i, exclude: BattleParty) -> bool:
	for party in self_parties:
		if party != exclude and not party.total_soldier_is_disabled and party.grid_pos == pos:
			return true
	for party in enemy_parties:
		if party != exclude and not party.total_soldier_is_disabled and party.grid_pos == pos:
			return true
	return false

## 行動順序
var action_order: Array[BattleParty]:
	get:
		var battle_parties: Array[BattleParty] = []
		for party in self_parties:
			if not party.total_soldier_is_disabled:
				battle_parties.append(party)
		for party in enemy_parties:
			if not party.total_soldier_is_disabled:
				battle_parties.append(party)
		battle_parties.sort_custom(func(a: BattleParty, b: BattleParty) -> bool: return a.action_speed > b.action_speed)
		return battle_parties

## 開始戰鬥,一次性跑完整場模擬並寫入 battle_log
func start() -> void:
	_init_battle()
	while _round < _total_round:
		if _judge_over():
			return
		_round_start()
		round_progress()
		_round_end()
	log_event({"type": "battle_draw"})

func _init_battle() -> void:
	log_event({"type": "battle_start"})

func _round_start() -> void:
	log_event({"type": "round_start", "round": _round + 1})

## 回合進行
func round_progress() -> void:
	for party in action_order:
		if _judge_over():
			return
		if not party.total_soldier_is_disabled:
			party.action()

func _round_end() -> void:
	log_event({"type": "round_end", "round": _round + 1})
	_round += 1

func _judge_over() -> bool:
	if self_party_leader.total_soldier_is_disabled:
		log_event({"type": "leader_defeated", "side_label": "我方", "party_name": self_party_leader.name})
		return true
	if enemy_party_leader.total_soldier_is_disabled:
		log_event({"type": "leader_defeated", "side_label": "敵方", "party_name": enemy_party_leader.name})
		return true
	return false

## 記錄一筆結構化戰報事件,並同步輸出除錯文字
func log_event(event: Dictionary) -> void:
	battle_log.append(event)
	print(_format_event(event))

func _format_event(event: Dictionary) -> String:
	match event.type:
		"battle_start":
			return "戰鬥開始"
		"round_start":
			return "------------第%d回------------" % event.round
		"round_end":
			return "回合結束"
		"move":
			return "%s move to %s" % [event.actor_name, event.target_name]
		"attack":
			return "%s attack %s" % [event.actor_name, event.target_name]
		"dodge":
			return "%s dodge from %s" % [event.target_name, event.actor_name]
		"daze":
			return "%s daze" % event.actor_name
		"skill":
			return "%s use skill %s to %s" % [event.actor_name, event.skill_name, event.target_name]
		"damage":
			return "%s got %d damage" % [event.target_name, event.damage_points]
		"soldier_casualty":
			return "%s 的 %s death: %d and wounded: %d" % [event.party_name, event.soldier_name, event.death_count, event.wounded_count]
		"all_disabled":
			return "%s all soldiers is disabled" % event.party_name
		"leader_defeated":
			return "%s總大將%s敗退" % [event.side_label, event.party_name]
		"battle_draw":
			return "已達最大回合數，戰鬥平局"
		_:
			return str(event)
