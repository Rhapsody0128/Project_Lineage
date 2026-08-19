extends Node

# =========================================================
# 玩家對六大國家(GameEnums.BloodlineNation)的好感度(autoload,見 project.godot)。
# 跟 BaseResourceStore 同一套慣例:這是 Scenes 層的 session 狀態(玩家目前數值),不是
# 規則邏輯——國家本身的靜態資料(名稱/低血/高血稱呼)在 System/nation/nation_library.gd。
# 目前只負責記錄好感度數值,依好感度升級城鎮功能是之後的事,這裡先不做任何等級換算。
# =========================================================

## 好感度變動時發出,讓已經開著的好感度 UI 能即時反映最新數字。
signal changed

var favors: Dictionary = {}


func get_favor(nation_id: int) -> int:
	return favors.get(nation_id, 0)


func add_favor(nation_id: int, amount: int) -> void:
	favors[nation_id] = get_favor(nation_id) + amount
	changed.emit()
