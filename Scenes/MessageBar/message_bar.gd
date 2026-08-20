extends CanvasLayer

# =========================================================
# 全域共用的頂部訊息條(autoload,見 project.godot),任何場景呼叫
# MessageBar.show_message("文字") 即可跳出一則小提示,浮在畫面最上方置中,
# 淡入 → 停留 → 淡出。同一時間只顯示一則,呼叫時若已有訊息在播放就排隊,
# 依序播放,不會互相打斷或疊在一起。
# =========================================================

const _FADE_DURATION := 0.3
const _DISPLAY_DURATION := 5.0

@onready var bar: Control = $Root/Bar
@onready var label: Label = $Root/Bar/Label

var _queue: Array[String] = []
var _is_showing := false


func _ready() -> void:
	bar.modulate.a = 0.0
	bar.visible = false
	label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	label.add_theme_font_size_override("font_size", 22)


func show_message(text: String) -> void:
	_queue.append(text)
	if not _is_showing:
		_show_next()


func _show_next() -> void:
	if _queue.is_empty():
		_is_showing = false
		return
	_is_showing = true
	label.text = _queue.pop_front()
	bar.modulate.a = 0.0
	bar.visible = true

	var tw := create_tween()
	tw.tween_property(bar, "modulate:a", 1.0, _FADE_DURATION)
	tw.tween_interval(_DISPLAY_DURATION - _FADE_DURATION * 2)
	tw.tween_property(bar, "modulate:a", 0.0, _FADE_DURATION)
	tw.tween_callback(_on_message_done)


func _on_message_done() -> void:
	bar.visible = false
	_show_next()
