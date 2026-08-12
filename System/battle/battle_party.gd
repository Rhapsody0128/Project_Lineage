class_name BattleParty
extends RefCounted

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

## 可行動表:key 為 "attack" / "daze" / 技能id,value 為權重
var action_chance_map: Dictionary = {}

func _init(p_party: Party, p_battle: Battle, p_is_enemy: bool) -> void:
	party = p_party
	battle = p_battle
	_is_enemy = p_is_enemy
	action_chance_map = {
		"attack": 25.0,
		"daze": 5.0,
	}
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

## 每回合的行動:參考信喵之野望的自動戰鬥 —— 敵人在攻擊範圍內才會出手,
## 否則就往最近的敵人前進一格,移動與行動互斥,同一回合只能擇一。
func action() -> void:
	var target := search_enemy()
	if target == null:
		return

	if _in_attack_range(target):
		var chosen_key: String = Util.get_random_chance_item(action_chance_map)
		if chosen_key == "attack":
			attack(target)
		elif chosen_key == "daze":
			daze()
		else:
			var skill: Skill = null
			for s in party.skill_list:
				if s.id == chosen_key:
					skill = s
					break
			if skill != null:
				skill.effect(self, target)
			else:
				daze()
	else:
		move(target)

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

## 往目標方向移動一格(先水平、後垂直),格子被佔用時原地停留
func move(target: BattleParty) -> void:
	var dx := 0
	var dy := 0

	if target.grid_pos.x != grid_pos.x:
		dx = sign(target.grid_pos.x - grid_pos.x)
	elif target.grid_pos.y != grid_pos.y:
		dy = sign(target.grid_pos.y - grid_pos.y)

	if dx == 0 and dy == 0:
		return

	var new_pos := Vector2i(grid_pos.x + dx, grid_pos.y + dy)

	if battle.is_occupied(new_pos):
		return

	battle.log_event({
		"type": "move", "actor": self, "actor_name": name,
		"target": target, "target_name": target.name,
		"from": grid_pos, "to": new_pos,
	})
	grid_pos = new_pos

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

## 判斷是否閃避
func judge_dodge(attacker: BattleParty, defender: BattleParty) -> bool:
	var dodge_rate: float = (defender.agility - attacker.perception * 1.2) * 0.45
	var roll := Util.get_random_int(0, 100)
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
