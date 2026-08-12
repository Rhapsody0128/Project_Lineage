class_name Troop
extends RefCounted

# =========================================================
# 軍團:由多個 Party(小隊)組成。目前軍團固定只有 1 個小隊,
# 之後小隊數量會是可被科技研發提升的變數。
# =========================================================

var name: String
var parties: Array[Party]

func _init(p_name: String, p_parties: Array[Party]) -> void:
	name = p_name
	parties = p_parties
