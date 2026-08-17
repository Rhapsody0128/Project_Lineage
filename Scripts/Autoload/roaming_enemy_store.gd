extends Node

# =========================================================
# 全程持有 RoamingEnemySpawner(比照 WorldTimeStore 持有 WorldTimeController 的模式)。
# 這是 Scenes 層的 session 單例,不是規則邏輯本身,所以放 Scripts/Autoload/ 不放 System/。
# 離開/返回 Scenes/Map/map.tscn 不會釋放這個 autoload,敵人清單(RoamingEnemySpawner.
# enemies)天生跨場景保留,不需要像 MapSessionStore 那樣額外寫存/讀快照程式碼。
# =========================================================

var spawner := RoamingEnemySpawner.new()
