extends Node

# =========================================================
# 全程持有 TravelEventRoller(比照 RoamingEnemyStore 持有 RoamingEnemySpawner 的模式)。
# 這是 Scenes 層的 session 單例,不是規則邏輯本身,所以放 Scripts/Autoload/ 不放 System/。
# =========================================================

var roller := TravelEventRoller.new()
