class_name Party
extends RefCounted

# =========================================================
# 小隊:由多個 Hero 組成的編隊單位。純粹是組織/編制上的分組,
# 不參與戰鬥判定——戰場上每個 Hero 都是各自獨立的作戰單位
# (見 System/battle/battle_hero.gd),Party 只負責「這個小隊裡有哪些角色」。
# =========================================================

var name: String
var heroes: Array[Hero]

func _init(p_name: String, p_heroes: Array[Hero]) -> void:
	name = p_name
	heroes = p_heroes
