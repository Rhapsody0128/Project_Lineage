extends Node

# =========================================================
# 全域消息存取點(autoload,見 project.godot)。消息列表場景讀 entries 顯示清單;
# NewsController(System/news/news_controller.gd)是唯一寫入端,其他事件要發布
# 消息一律呼叫 NewsController.post(),不要直接呼叫這裡。
# =========================================================

var entries: Array[NewsEntry] = []

func add_entry(entry: NewsEntry) -> void:
	entries.append(entry)
