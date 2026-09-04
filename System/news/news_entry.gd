class_name NewsEntry
extends RefCounted

## 一則永久留存的消息紀錄,見 System/news/news_controller.gd 的唯一寫入端。
## game_time_text 是遊戲內曆法時間(WorldTime 格式化字串,例如「第3年 春 15日」),
## system_time_text 是這則消息實際寫入當下的真實系統時間(_format_system_time()),
## 兩者用途不同、不能互相取代——前者給玩家看「遊戲裡何時發生」,後者純粹除錯/
## 時間軸排序用,news_list.gd 目前只顯示前者。is_read 新建時固定 false,見
## NewsStore.mark_category_read() 唯一的標記已讀入口。

var id: String
var content: String
var game_time_text: String
var system_time_text: String
var category: GameEnums.NewsCategory
var is_read: bool

func _init(p_content: String, p_game_time_text: String, p_category: GameEnums.NewsCategory) -> void:
	id = Util.generate_uuid()
	content = p_content
	game_time_text = p_game_time_text
	system_time_text = _format_system_time()
	category = p_category
	is_read = false

static func _format_system_time() -> String:
	var dt := Time.get_datetime_dict_from_system()
	return "%04d/%02d/%02d %02d:%02d:%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second]
