class_name NewsEntry
extends RefCounted

var id: String
var content: String
var game_time_text: String
var system_time_text: String

func _init(p_content: String, p_game_time_text: String) -> void:
	id = Util.generate_uuid()
	content = p_content
	game_time_text = p_game_time_text
	system_time_text = _format_system_time()

static func _format_system_time() -> String:
	var dt := Time.get_datetime_dict_from_system()
	return "%04d/%02d/%02d %02d:%02d:%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second]
