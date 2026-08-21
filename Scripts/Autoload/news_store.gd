extends Node

# =========================================================
# 全域消息存取點(autoload,見 project.godot)。消息列表場景讀 entries 顯示清單;
# NewsController(System/news/news_controller.gd)是唯一寫入端,其他事件要發布
# 消息一律呼叫 NewsController.post(),不要直接呼叫這裡。
# =========================================================

var entries: Array[NewsEntry] = []

func add_entry(entry: NewsEntry) -> void:
	entries.append(entry)


func to_save_data() -> Array:
	var result: Array = []
	for entry in entries:
		result.append({
			"content": entry.content,
			"game_time_text": entry.game_time_text,
			"system_time_text": entry.system_time_text,
		})
	return result


func load_save_data(data: Array) -> void:
	entries.clear()
	for entry_data in data:
		var entry := NewsEntry.new(entry_data.get("content", ""), entry_data.get("game_time_text", ""))
		entry.system_time_text = entry_data.get("system_time_text", entry.system_time_text)
		entries.append(entry)
