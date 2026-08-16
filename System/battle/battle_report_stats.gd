class_name BattleReportStats
extends RefCounted

## 戰報統計面板(Scenes/BattleReportStats)專用:把一場已經跑完模擬的 Battle 攤開成
## 「每個角色血量變化」+「戰鬥結果統計表」需要的數字。一律從 battle.battle_log 重新
## 彙總,不讀角色目前 hp——玩家可能已經先進 Battle 場景重播過這份戰報,character.hp 會被
## 改到重播進度,不能拿來當統計數字用。
##
## 傷害/技能施放的歸屬:DamageEvent 本身不記 actor(見該檔案註解),只能靠戰報事件的
## 記錄順序反推——BattleCharacter.attack()/SkillEffectLibrary._cast_attack_skill()/
## Ultimate.resolve() 都是「先記一筆 Attack/Skill/UltimateResolve 事件,緊接著才記
## 造成的 Damage/Heal 事件」,兩者之間不會插入其他角色的行動事件,所以掃描時只要記住
## 「目前正在處理誰的行動」,後面連續出現的 Damage 事件就歸給它。

var result: GameEnums.BattleResultType
var result_text: String
var rounds_used: int
var end_reason_text: String

## 每筆 {name, face_path, start_hp, end_hp, hp_max}
var self_character_rows: Array[Dictionary] = []
var enemy_character_rows: Array[Dictionary] = []

var top_damage_name: String = ""
var top_damage_value: int = 0
var top_guard_name: String = ""
var top_guard_value: int = 0
var top_skill_name: String = ""
var top_skill_value: int = 0
var ultimate_use_count: int = 0

func _init(battle: Battle) -> void:
	var end_event := battle.battle_end_event
	result = end_event.result
	rounds_used = end_event.round
	result_text = _result_text(result)

	var damage_by_actor: Dictionary = {} # actor_name -> int
	var guard_by_actor: Dictionary = {} # actor_name -> int
	var skill_by_actor: Dictionary = {} # actor_name -> int
	var defeated_characteres: Dictionary = {} # BattleCharacter -> true
	var final_hp: Dictionary = {} # BattleCharacter -> int
	var current_actor_name := ""

	for event in battle.battle_log:
		if event is AttackEvent:
			current_actor_name = event.actor_name
		elif event is SkillEvent:
			current_actor_name = event.actor_name
			skill_by_actor[event.actor_name] = skill_by_actor.get(event.actor_name, 0) + 1
		elif event is UltimateResolveEvent:
			current_actor_name = event.actor_name
			ultimate_use_count += 1
		elif event is GuardEvent:
			guard_by_actor[event.actor_name] = guard_by_actor.get(event.actor_name, 0) + 1
		elif event is DamageEvent:
			final_hp[event.target] = event.remaining_hp
			if current_actor_name != "":
				damage_by_actor[current_actor_name] = damage_by_actor.get(current_actor_name, 0) + event.damage_points
		elif event is HealEvent:
			final_hp[event.target] = event.remaining_hp
		elif event is DefeatedEvent:
			defeated_characteres[event.party] = true

	var top_damage := _pick_top(damage_by_actor)
	top_damage_name = top_damage[0]
	top_damage_value = top_damage[1]

	var top_guard := _pick_top(guard_by_actor)
	top_guard_name = top_guard[0]
	top_guard_value = top_guard[1]

	var top_skill := _pick_top(skill_by_actor)
	top_skill_name = top_skill[0]
	top_skill_value = top_skill[1]

	self_character_rows = _build_character_rows(battle, battle.self_characteres, final_hp)
	enemy_character_rows = _build_character_rows(battle, battle.enemy_characteres, final_hp)
	end_reason_text = _end_reason_text(battle, result, defeated_characteres)


static func _result_text(p_result: GameEnums.BattleResultType) -> String:
	match p_result:
		GameEnums.BattleResultType.SELF_WIN:
			return "勝利"
		GameEnums.BattleResultType.ENEMY_WIN:
			return "戰敗"
		_:
			return "平手"


static func _build_character_rows(battle: Battle, battle_characteres: Array[BattleCharacter], final_hp: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for battle_character in battle_characteres:
		var start_hp := battle.start_hp(battle_character)
		rows.append({
			"name": battle_character.name,
			"face_path": battle_character.character.face_path,
			"start_hp": start_hp,
			"end_hp": final_hp.get(battle_character, start_hp),
			"hp_max": battle_character.hp_max,
		})
	return rows


## 依次數取最高的一筆,回傳 [name, value];沒有任何記錄時回傳 ["", 0]。
static func _pick_top(counts: Dictionary) -> Array:
	var best_name := ""
	var best_value := 0
	for actor_name: String in counts:
		var value: int = counts[actor_name]
		if value > best_value:
			best_value = value
			best_name = actor_name
	return [best_name, best_value]


## 平手一律是撐滿 10 回合(見 Battle.result 註解);勝負分明時,再看輸的一方是被打到
## 全滅、還是只有隊長(總大將)陣亡就分出勝負。
static func _end_reason_text(
	battle: Battle, p_result: GameEnums.BattleResultType, defeated_characteres: Dictionary
) -> String:
	if p_result == GameEnums.BattleResultType.DRAW:
		return "回合結束"

	var losing_side: Array[BattleCharacter] = (
		battle.enemy_characteres if p_result == GameEnums.BattleResultType.SELF_WIN else battle.self_characteres
	)
	var defeated_count := 0
	for battle_character in losing_side:
		if defeated_characteres.has(battle_character):
			defeated_count += 1

	return "全員擊破" if defeated_count >= losing_side.size() else "隊長擊破"
