class_name Battle
extends RefCounted

## 戰場格子大小,參考信喵之野望的縱向戰場:玩家在下方、敵方在上方,
## 6 路縱隊往中間推進交戰。左右(GRID_COLS)12 格、上下(GRID_ROWS)6 格。
const GRID_COLS := 12
const GRID_ROWS := 6

## 固定跑 10 回合結算,沒有「總大將陣亡即分勝負」的設計——回合數到了就比較
## 雙方剩餘總 HP,哪邊多哪邊贏
const TOTAL_ROUND := 10

var self_heroes: Array[BattleHero]
var enemy_heroes: Array[BattleHero]

var _round: int = 0

## 結構化戰報,依序記錄戰鬥中發生的每一個事件,供外部(UI/場景)重播使用
var battle_log: Array[Dictionary] = []

func _init(self_troop: Troop, enemy_troop: Troop) -> void:
	self_heroes = _attach_battle_heroes(false, self_troop)
	enemy_heroes = _attach_battle_heroes(true, enemy_troop)
	_deploy_initial_positions()

## 軍團底下有多個小隊、每個小隊有多個角色,但戰場上沒有「小隊」這個作戰單位——
## 攤平成一整排角色,每人各自佔一格獨立作戰。
func _attach_battle_heroes(is_enemy: bool, troop: Troop) -> Array[BattleHero]:
	var battle_heroes: Array[BattleHero] = []
	for party in troop.parties:
		for hero in party.heroes:
			battle_heroes.append(BattleHero.new(hero, self, is_enemy))
	return battle_heroes

## 初始佈陣:我方沿最左列、敵方沿最右列,各自置中排成一列縱隊的隊頭
func _deploy_initial_positions() -> void:
	var self_start_y := (GRID_ROWS - self_heroes.size()) / 2
	for i in range(self_heroes.size()):
		self_heroes[i].grid_pos = Vector2i(0, self_start_y + i)

	var enemy_start_y := (GRID_ROWS - enemy_heroes.size()) / 2
	for i in range(enemy_heroes.size()):
		enemy_heroes[i].grid_pos = Vector2i(GRID_COLS - 1, enemy_start_y + i)

## 該格子是否已有「其他」存活角色佔據(排除 exclude 自己)。
## 已戰敗的角色不算佔用 —— 移動途中可以直接穿過己方存活角色,
## 最終落腳點只需要避開所有「存活中」的角色(不分陣營),戰敗角色的位置可以站上去。
func is_occupied_excluding(pos: Vector2i, exclude: BattleHero) -> bool:
	for battle_hero in self_heroes:
		if battle_hero != exclude and not battle_hero.is_disabled and battle_hero.grid_pos == pos:
			return true
	for battle_hero in enemy_heroes:
		if battle_hero != exclude and not battle_hero.is_disabled and battle_hero.grid_pos == pos:
			return true
	return false

## 行動順序
var action_order: Array[BattleHero]:
	get:
		var battle_heroes: Array[BattleHero] = []
		for battle_hero in self_heroes:
			if not battle_hero.is_disabled:
				battle_heroes.append(battle_hero)
		for battle_hero in enemy_heroes:
			if not battle_hero.is_disabled:
				battle_heroes.append(battle_hero)
		battle_heroes.sort_custom(func(a: BattleHero, b: BattleHero) -> bool: return a.action_speed > b.action_speed)
		return battle_heroes

## 開始戰鬥,一次性跑完整場模擬並寫入 battle_log
func start() -> void:
	_init_battle()
	while _round < TOTAL_ROUND:
		_round_start()
		round_progress()
		_round_end()
	_conclude_battle()

func _init_battle() -> void:
	log_event({"type": "battle_start"})

func _round_start() -> void:
	log_event({"type": "round_start", "round": _round + 1})

## 回合進行:全滅的一方沒有敵人可打,action() 內部 search_enemy() 找不到目標會自動
## 提前 return,不需要另外判斷戰鬥是否已經分出勝負
func round_progress() -> void:
	for battle_hero in action_order:
		if not battle_hero.is_disabled:
			battle_hero.action()

func _round_end() -> void:
	log_event({"type": "round_end", "round": _round + 1})
	_round += 1

## 跑滿 TOTAL_ROUND 回合後結算:比較雙方剩餘總 HP,HP 多的一方獲勝
func _conclude_battle() -> void:
	log_event({
		"type": "battle_end",
		"self_total": self_total_hp,
		"enemy_total": enemy_total_hp,
	})

var self_total_hp: int:
	get: return _sum_hp(self_heroes)
var enemy_total_hp: int:
	get: return _sum_hp(enemy_heroes)

func _sum_hp(battle_heroes: Array[BattleHero]) -> int:
	var total := 0
	for battle_hero in battle_heroes:
		total += battle_hero.hp
	return total

## 記錄一筆結構化戰報事件,並同步輸出除錯文字
func log_event(event: Dictionary) -> void:
	battle_log.append(event)
	print(_format_event(event))

func _format_event(event: Dictionary) -> String:
	match event.type:
		"battle_start":
			return "戰鬥開始"
		"round_start":
			return "------------第 %d 回合------------" % event.round
		"round_end":
			return "回合結束"
		"move":
			if event.get("away", false):
				return "%s 遠離 %s" % [event.actor_name, event.target_name]
			return "%s 接近 %s" % [event.actor_name, event.target_name]
		"attack":
			return "%s 攻擊 %s" % [event.actor_name, event.target_name]
		"dodge":
			return "%s 閃避了 %s 的攻擊" % [event.target_name, event.actor_name]
		"daze":
			return "%s 猶豫不決" % event.actor_name
		"skill":
			return "%s 對 %s 使用技能「%s」" % [event.actor_name, event.target_name, event.skill_name]
		"damage":
			return "%s 受到 %d 點傷害(剩餘 HP %d)" % [event.target_name, event.damage_points, event.remaining_hp]
		"defeated":
			return "%s 戰敗" % event.party_name
		"battle_end":
			return "戰鬥結束，我方剩餘 HP %d，敵方剩餘 HP %d" % [event.self_total, event.enemy_total]
		_:
			return str(event)
