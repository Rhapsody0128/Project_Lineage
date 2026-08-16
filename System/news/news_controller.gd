class_name NewsController
extends RefCounted

## 給其他系統/事件呼叫來發布一則消息(例如聯姻結果、城堡事件等),
## 一步到位產生 NewsEntry 並存進 NewsStore,呼叫端不用另外處理存檔。
static func post(content: String) -> NewsEntry:
	var entry := NewsEntry.new(content, WorldTimeStore.get_display_string())
	NewsStore.add_entry(entry)
	return entry
