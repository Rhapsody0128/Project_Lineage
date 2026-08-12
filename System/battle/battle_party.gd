class_name BattleParty
extends RefCounted

## 每回合預設移動步數
const BASE_MOVE_STEPS := 2
## 每累積這麼多敏捷,多走 1 格
const AGILITY_PER_EXTRA_STEP := 25.0

var party: Party
var battle: Battle

var _is_enemy: bool

var _strength_const: float = 1.0
var _agility_const: float = 1.0
var _perception_const: float = 1.0
var _vitality_const: float = 1.0
var _intelligence_const: float = 1.0
var _mentality_const: float = 1.0

## 戰場格子座標,由 Battle 佈陣時指定初始值,戰鬥中隨 move() 更新
var grid_pos: Vector2i

## 可施放技能表:key 為技能 id,value 為權重(action() 抽中 SKILL 時,
## 用這張表決定實際施放哪一個技能)
var action_chance_map: Dictionary = {}

func _init(p_party: Party, p_battle: Battle, p_is_enemy: bool) -> void:
	party = p_party
	battle = p_battle
	_is_enemy = p_is_enemy
	_set_action_chance()

func _set_action_chance() -> void:
	for skill in party.skill_list:
		var equipped_weapon := weapon
		var equipped_weapon_type: int = equipped_weapon.weapon_type if equipped_weapon != null else GameEnums.WeaponType.EMPTY
		if skill.bind_weapon == equipped_weapon_type or skill.bind_weapon == GameEnums.WeaponType.EMPTY:
			var chance: float = skill.base_chance
			if skill.skill_type == position_skill_type:
				chance *= 1.5
			action_chance_map[skill.id] = chance

## 每回合抽一次行動類型的權重表:ATTACK/DAZE/SKILL 固定各 25,
## ESCAPE 只有在兵力低於 50% 時才會被列入(權重 25),
## CONFUSE(叛變攻擊己方)暫時移除抽選,等魅惑狀態系統接上後再開放。
func _build_action_type_chance_map() -> Dictionary:
	var map := {
		"ATTACK": 25.0,
		"DAZE": 25.0,
		"SKILL": 25.0,
	}
	if hp_ratio < 0.5:
		map["ESCAPE"] = 25.0
	return map

## 每回合的行動:先依權重抽出行動類型,再依類型決定實際行為。
## ATTACK/SKILL 需要進入攻擊範圍才能出手,尚未進入範圍時改為往目標移動;
## DAZE 原地不動;ESCAPE(兵力低於 50% 才可能抽到)遠離目標。
func action() -> void:
	var target := search_enemy()
	if target == null:
		return

	var action_type: String = Util.get_random_chance_item(_build_action_type_chance_map())

	match action_type:
		"DAZE":
			daze()
		"ESCAPE":
			move_away(target)
		"SKILL":
			if _in_attack_range(target):
				_cast_random_skill(target)
			else:
				move(target)
		_: # "ATTACK"
			if _in_attack_range(target):
				attack(target)
			else:
				move(target)

## SKILL 類型:依 action_chance_map 抽一個技能施放,沒有可用技能時退化成一般攻擊
func _cast_random_skill(target: BattleParty) -> void:
	if action_chance_map.is_empty():
		attack(target)
		return

	var chosen_id: String = Util.get_random_chance_item(action_chance_map)
	var skill: Skill = null
	for s in party.skill_list:
		if s.id == chosen_id:
			skill = s
			break

	if skill != null:
		skill.effect(self, target)
	else:
		attack(target)

## CONFUSE:叛變攻擊己方隊友。目前 action() 暫時不會抽到這個類型
## (等魅惑狀態系統接上、能限定只有被魅惑時才抽得到再開放),
## 機制先保留在這裡備用;找不到可攻擊的隊友時退化成原地發呆。
func _confuse_attack() -> void:
	var living_allies := allies
	if living_allies.is_empty():
		daze()
		return

	var victim: BattleParty = Util.get_random_from_array(living_allies)
	attack(victim)

func attack(target: BattleParty) -> void:
	battle.log_event({"type": "attack", "actor": self, "actor_name": name, "target": target, "target_name": target.name})
	if judge_dodge(self, target):
		return
	var damage_base: float = strength
	var reduce_base: float = target.vitality
	var damage: float = damage_base - (damage_base * (reduce_base / 200.0))
	target.be_attacked(damage)

func daze() -> void:
	battle.log_event({"type": "daze", "actor": self, "actor_name": name})

## 往目標方向移動,最多走 move_steps 格(先水平、後垂直);
## 途中會直接穿過己方角色(不擋路),只有敵方角色會擋路,
## 遇到敵方卡住主方向時會側移繞路,而不是直接卡死不動。
## 整趟移動只記一筆 move 事件(內含完整路徑),讓畫面端可以連續播放,
## 不必每格都停頓。
func move(target: BattleParty) -> void:
	_move_towards_or_away(target, false)

## ESCAPE 類型用:往目標的反方向移動(遠離戰場),其餘規則與 move() 相同
## (可穿過己方、只有敵方擋路、最終落腳點需淨空)。
func move_away(target: BattleParty) -> void:
	_move_towards_or_away(target, true)

func _move_towards_or_away(target: BattleParty, away: bool) -> void:
	var start_pos := grid_pos
	var path: Array[Vector2i] = []

	for i in range(move_steps):
		if not away and _in_attack_range(target):
			break

		var new_pos := _next_step(target, away)
		if new_pos == grid_pos:
			break

		grid_pos = new_pos
		path.append(new_pos)

	# 移動途中可以直接穿過己方角色,但最終落腳點不能剛好疊在任何人身上,
	# 若最後一步撞上己方角色所在位置,就退回到前一步(空格)停下。
	while not path.is_empty() and battle.is_occupied_excluding(path[path.size() - 1], self):
		path.remove_at(path.size() - 1)
		grid_pos = path[path.size() - 1] if not path.is_empty() else start_pos

	if path.is_empty():
		grid_pos = start_pos
		return

	battle.log_event({
		"type": "move", "actor": self, "actor_name": name,
		"target": target, "target_name": target.name,
		"from": start_pos, "path": path, "to": path[path.size() - 1], "away": away,
	})

## 計算朝目標前進(或遠離,away=true)的下一步:優先走能縮短(或拉開)距離的主方向,
## 只有敵方角色會擋路(己方可直接穿過);若被敵方卡住,
## 改往另一軸側移繞路(挑選能讓距離更符合目的——靠近或遠離——的一側),
## 全部候選都走不了時回傳原地(呼叫端視為卡死、停止移動)。
func _next_step(target: BattleParty, away: bool) -> Vector2i:
	var dx := 0
	var dy := 0

	if target.grid_pos.x != grid_pos.x:
		dx = sign(target.grid_pos.x - grid_pos.x)
	elif target.grid_pos.y != grid_pos.y:
		dy = sign(target.grid_pos.y - grid_pos.y)

	if away:
		dx = -dx
		dy = -dy

	if dx == 0 and dy == 0:
		return grid_pos

	var primary := Vector2i(grid_pos.x + dx, grid_pos.y + dy)
	if _is_within_board(primary) and not _is_blocked_by_enemy(primary):
		return primary

	var sidesteps: Array[Vector2i] = []
	if dx != 0:
		sidesteps.append(Vector2i(grid_pos.x, grid_pos.y - 1))
		sidesteps.append(Vector2i(grid_pos.x, grid_pos.y + 1))
	else:
		sidesteps.append(Vector2i(grid_pos.x - 1, grid_pos.y))
		sidesteps.append(Vector2i(grid_pos.x + 1, grid_pos.y))

	sidesteps.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := _manhattan(a, target.grid_pos)
		var db := _manhattan(b, target.grid_pos)
		return da > db if away else da < db
	)

	for c in sidesteps:
		if _is_within_board(c) and not _is_blocked_by_enemy(c):
			return c

	return grid_pos

## 只有敵方(存活中)會擋路,己方角色不會阻擋移動路徑
func _is_blocked_by_enemy(pos: Vector2i) -> bool:
	for e in enemies:
		if e.grid_pos == pos:
			return true
	return false

func _is_within_board(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < Battle.GRID_COLS and pos.y >= 0 and pos.y < Battle.GRID_ROWS

func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

## 本回合可移動的格數:基礎 2 格,每 25 敏捷多走 1 格
var move_steps: int:
	get: return BASE_MOVE_STEPS + int(agility / AGILITY_PER_EXTRA_STEP)

## 是否進入攻擊範圍(以格子曼哈頓距離判定,相鄰即可)
func _in_attack_range(target: BattleParty) -> bool:
	var d: int = abs(target.grid_pos.x - grid_pos.x) + abs(target.grid_pos.y - grid_pos.y)
	return d <= 1

## 找尋最近的敵人(以格子曼哈頓距離判定)
func search_enemy() -> BattleParty:
	var best: BattleParty = null
	var best_dist := -1
	for other in enemies:
		var d: int = abs(other.grid_pos.x - grid_pos.x) + abs(other.grid_pos.y - grid_pos.y)
		if best == null or d < best_dist:
			best_dist = d
			best = other
	return best

## 受到攻擊時
func be_attacked(damage: float) -> void:
	var damage_points: int = roundi(damage)
	battle.log_event({"type": "damage", "target": self, "target_name": name, "damage_points": damage_points})

	var soldiers := party.soldiers
	while damage_points > 0:
		if total_soldier_is_disabled:
			battle.log_event({"type": "all_disabled", "party": self, "party_name": name})
			return

		var random_index := Util.get_random_int(0, soldiers.size())
		var soldier: Soldier = soldiers[random_index]

		if soldier.is_disabled:
			continue

		var avoid_death_rate: float = (20 + Util.get_random_int(0, 20) + (vitality / 200.0) * 40) / 100.0

		if soldier.soldiers_count >= damage_points:
			var death_count := roundi(damage_points * (1.0 - avoid_death_rate))
			var wounded_count := roundi(damage_points * avoid_death_rate)
			soldier.death_soldiers_count += death_count
			soldier.wounded_soldiers_count += wounded_count
			damage_points = 0
			battle.log_event({
				"type": "soldier_casualty", "party": self, "party_name": name,
				"soldier_name": soldier.name, "death_count": death_count, "wounded_count": wounded_count,
				"remaining_count": total_soldier_count,
			})
		else:
			var remain_soldier := soldier.soldiers_count
			var death_count := roundi(remain_soldier * (1.0 - avoid_death_rate))
			var wounded_count := roundi(remain_soldier * avoid_death_rate)
			soldier.death_soldiers_count += death_count
			soldier.wounded_soldiers_count += wounded_count
			damage_points -= remain_soldier
			battle.log_event({
				"type": "soldier_casualty", "party": self, "party_name": name,
				"soldier_name": soldier.name, "death_count": death_count, "wounded_count": wounded_count,
				"remaining_count": total_soldier_count,
			})

## 判斷是否閃避:防禦方 AGI(敏捷)vs 攻擊方 DEX(此處以 perception 當作命中判定用的
## DEX 數值,專案目前沒有獨立的 DEX 屬性)。雙方數值都是 0~200,兩者相等時對半開(50%),
## 每差 200(整個數值範圍)偏移 45 個百分點,並夾在 [5, 95] 之間 —— 保證
## 「AGI 拉滿(200)vs DEX 掉零(0)」時攻擊方依然有 5% 保底命中,同時鏡射保證
## 「DEX 拉滿 vs AGI 掉零」時防禦方也有 5% 保底閃避,雙方永遠不會被完全鎖死。
const DODGE_RATE_MIN := 5.0
const DODGE_RATE_MAX := 95.0
const DODGE_RATE_NEUTRAL := 50.0
const DODGE_RATE_SCALE := 0.225 # 45 / 200

func judge_dodge(attacker: BattleParty, defender: BattleParty) -> bool:
	var dodge_rate: float = clampf(
		DODGE_RATE_NEUTRAL + (defender.agility - attacker.perception) * DODGE_RATE_SCALE,
		DODGE_RATE_MIN,
		DODGE_RATE_MAX
	)
	var roll := Util.get_random_float(0.0, 100.0)
	if roll < dodge_rate:
		battle.log_event({"type": "dodge", "actor": attacker, "actor_name": attacker.name, "target": defender, "target_name": defender.name})
		return true
	return false

## 敵人列表(存活中)
var enemies: Array[BattleParty]:
	get:
		var source: Array[BattleParty] = battle.self_parties if _is_enemy else battle.enemy_parties
		var result: Array[BattleParty] = []
		for p in source:
			if not p.total_soldier_is_disabled:
				result.append(p)
		return result

## 隊友列表(存活中,不含自己;CONFUSE 叛變攻擊用)
var allies: Array[BattleParty]:
	get:
		var source: Array[BattleParty] = battle.enemy_parties if _is_enemy else battle.self_parties
		var result: Array[BattleParty] = []
		for p in source:
			if p != self and not p.total_soldier_is_disabled:
				result.append(p)
		return result

## 敵人主將
var enemy_leader: BattleParty:
	get:
		if not _is_enemy:
			return battle.enemy_party_leader
		else:
			return battle.self_party_leader

var total_soldier_count: int:
	get:
		var total := 0
		for soldier in party.soldiers:
			total += soldier.soldiers_count
		return total

var total_soldier_count_max: int:
	get:
		var total := 0
		for soldier in party.soldiers:
			total += soldier.soldiers_count_max
		return total

## 目前兵力比例(當前/最大),ESCAPE 是否列入抽選就看這個
var hp_ratio: float:
	get:
		var max_count := total_soldier_count_max
		if max_count <= 0:
			return 0.0
		return float(total_soldier_count) / float(max_count)

var total_wounded_soldier_count: int:
	get:
		var total := 0
		for soldier in party.soldiers:
			total += soldier.wounded_soldiers_count
		return total

var total_soldier_is_disabled: bool:
	get:
		for soldier in party.soldiers:
			if not soldier.is_disabled:
				return false
		return true

var weapon: Weapon:
	get: return party.weapon

var position_skill_type:
	get: return party.position_skill_type

var name: String:
	get: return party.name

var strength: float:
	get: return party.strength * _strength_const
var agility: float:
	get: return party.agility * _agility_const
var perception: float:
	get: return party.perception * _perception_const
var vitality: float:
	get: return party.vitality * _vitality_const
var intelligence: float:
	get: return party.intelligence * _intelligence_const
var mentality: float:
	get: return party.mentality * _mentality_const

## 行動速度(回合排序用),暫以敏捷做為速度來源
var action_speed: float:
	get: return agility
