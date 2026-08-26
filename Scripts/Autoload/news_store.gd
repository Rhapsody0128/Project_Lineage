extends Node

# =========================================================
# 全域消息存取點(autoload,見 project.godot)。消息列表場景讀 entries 顯示清單;
# NewsController(System/news/news_controller.gd)是唯一寫入端,其他事件要發布
# 消息一律呼叫 NewsController.post(),不要直接呼叫這裡。
# =========================================================

var entries: Array[NewsEntry] = []

func add_entry(entry: NewsEntry) -> void:
	entries.append(entry)


## 消息列表場景「打開分頁=該分頁全部已讀」時呼叫——把該分類目前所有消息一次標記已讀,
## 之後同一則消息不會再顯示未讀標示(見 Scenes/News/news_list.gd)。
func mark_category_read(category: GameEnums.NewsCategory) -> void:
	for entry in entries:
		if entry.category == category:
			entry.is_read = true


func to_save_data() -> Array:
	var result: Array = []
	for entry in entries:
		result.append({
			"content": entry.content,
			"game_time_text": entry.game_time_text,
			"system_time_text": entry.system_time_text,
			"category": entry.category,
			"is_read": entry.is_read,
		})
	return result


func load_save_data(data: Array) -> void:
	entries.clear()
	for entry_data in data:
		var entry := NewsEntry.new(
			entry_data.get("content", ""),
			entry_data.get("game_time_text", ""),
			entry_data.get("category", GameEnums.NewsCategory.MAJOR)
		)
		entry.system_time_text = entry_data.get("system_time_text", entry.system_time_text)
		entry.is_read = entry_data.get("is_read", true)
		entries.append(entry)
