class_name Party
extends RefCounted

# =========================================================
# 小隊:由多個 Hero 組成的編隊單位。純粹是組織/編制上的分組,
# 不參與戰鬥判定——戰場上每個 Hero 都是各自獨立的作戰單位
# (見 System/battle/battle_hero.gd),Party 只負責「這個小隊裡有哪些角色」。
# =========================================================

var name: String
var heroes: Array[Hero]
## 隊長:目前只用來在戰場上標示(金色外框)與判斷隊長陣亡即結束戰鬥,
## 不影響小隊本身的組織邏輯。未指定時預設隊伍第一位角色。
var leader: Hero

func _init(p_name: String, p_heroes: Array[Hero], p_leader: Hero = null) -> void:
	name = p_name
	heroes = p_heroes
	leader = p_leader if p_leader != null else (heroes[0] if not heroes.is_empty() else null)
