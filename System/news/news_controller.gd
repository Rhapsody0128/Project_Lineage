class_name NewsController
extends RefCounted

## 給其他系統/事件呼叫來發布一則消息(例如聯姻結果、城鎮事件等),
## 一步到位產生 NewsEntry 並存進 NewsStore,呼叫端不用另外處理存檔。
## category 一律要明確指定(GameEnums.NewsCategory),對應 Scenes/News/news_list.gd
## 的「重大」/「日常」分頁,不給預設值——呼叫端要自己想清楚這則消息算哪一類。
static func post(content: String, category: GameEnums.NewsCategory) -> NewsEntry:
	var entry := NewsEntry.new(content, WorldTimeStore.get_display_string(), category)
	NewsStore.add_entry(entry)
	return entry
