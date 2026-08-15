class_name Party
extends RefCounted

# =========================================================
# 小隊:由多個 Hero 組成的編隊單位。純粹是組織/編制上的分組,
# 不參與戰鬥判定——戰場上每個 Hero 都是各自獨立的作戰單位
# (見 System/battle/battle_hero.gd),Party 只負責「這個小隊裡有哪些角色」。
# =========================================================

var name: String
var heroes: Array[Hero]
## 隊長:目前只用來在戰場上標示(金色遮罩)與判斷隊長陣亡即結束戰鬥,
## 不影響小隊本身的組織邏輯。未指定時預設隊伍第一位角色。
var leader: Hero

## PartyEdit 編成時記錄的站位(Hero -> PartyEditGrid 座標,即該角色 battle_cost
## 佔位格/軸心落在網格上的位置)。Battle 開戰佈陣時(見 battle.gd 的
## _deploy_side())如果查得到某個角色的站位,直接照這個位置站,不套用預設的
## 靠邊縱隊排法。PartyController.get_random_party() 生的隨機小隊不會記錄任何
## 站位,一律吃預設佈陣,兩種小隊可以混合出現(例如玩家小隊 vs 隨機敵方小隊)、
## 互不影響。
var battle_cost_positions: Dictionary = {}  # Hero -> Vector2i

## 這個小隊在戰鬥中可施放的奧義(見 System/ultimate/),即時戰鬥模式
## (Battle.start_realtime())才會用到,由 PartyController 建立小隊時指派預設值
## (UltimateLibrary.default_ultimates())。
var ultimates: Array[Ultimate] = []

func _init(p_name: String, p_heroes: Array[Hero], p_leader: Hero = null) -> void:
	name = p_name
	heroes = p_heroes
	leader = p_leader if p_leader != null else (heroes[0] if not heroes.is_empty() else null)

func set_battle_position(hero: Hero, cell: Vector2i) -> void:
	battle_cost_positions[hero] = cell

func has_battle_position(hero: Hero) -> bool:
	return battle_cost_positions.has(hero)

func get_battle_position(hero: Hero) -> Vector2i:
	return battle_cost_positions.get(hero, Vector2i.ZERO)
