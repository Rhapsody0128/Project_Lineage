class_name RhythmBreakpointEditorView
extends Control

## 「斷點設定」畫面(RhythmBuildingPanel 的 E 按鈕):播 BGM,設計者按 Space 或滑鼠左鍵在
## 樂句/段落分界處打點,記錄當下時間戳當斷點,存檔寫進 RhythmChartStore.save_break_points()
## ——結構完全比照 RhythmRecordView 的「播放+記錄」骨架,差別只在記錄的是斷點而非提示/正確
## 譜音符,也不分 variant(斷點是同一份 BGM 素材本身的結構,常規版/變奏版共用)。進畫面時會
## 先讀出既有斷點方便設計者知道目前狀態;按「開始」後會清空重新記錄一輪,「儲存」才真正
## 覆蓋寫回。

signal back_requested

const DURATION_SEC := RhythmChart.CHART_DURATION_SEC

var _building_type: GameEnums.BuildingType = -1
var _bgm_player: AudioStreamPlayer
var _tap_sfx_player: AudioStreamPlayer
var _hit_sfx_path: String = ""

var _existing_break_points: Array[float] = []
var _recorded_points: Array[float] = []
var _is_playing := false
var _clock := RhythmClock.new()

var _progress_bar: ProgressBar
var _list_label: Label
var _start_button: Button
var _save_button: Button
var _retry_button: Button


func setup(
	building_type: GameEnums.BuildingType,
	bgm_player: AudioStreamPlayer,
	tap_sfx_player: AudioStreamPlayer
) -> void:
	_building_type = building_type
	_bgm_player = bgm_player
	_tap_sfx_player = tap_sfx_player
	_hit_sfx_path = RhythmChartStore.hit_sfx_path_for(building_type)
	_existing_break_points = RhythmChartStore.load_break_points(building_type)
	_build_layout()


func _build_layout() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 12)
	add_child(column)

	var title := Label.new()
	title.text = "正在設定斷點（Space 或滑鼠左鍵在段落分界處打點，共 %.0f 秒，目前已存 %d 個斷點）" % [
		DURATION_SEC, _existing_break_points.size()
	]
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	title.add_theme_font_size_override("font_size", 20)
	column.add_child(title)

	_progress_bar = ProgressBar.new()
	_progress_bar.max_value = 100.0
	_progress_bar.value = 0.0
	column.add_child(_progress_bar)

	_list_label = Label.new()
	_list_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	column.add_child(_list_label)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 12)
	column.add_child(button_row)

	_start_button = Button.new()
	_start_button.text = "開始"
	UiStyle.apply_wood_plaque_button(_start_button, 20.0, 10.0)
	_start_button.pressed.connect(_on_start_pressed)
	button_row.add_child(_start_button)

	_save_button = Button.new()
	_save_button.text = "儲存"
	UiStyle.apply_wood_plaque_button(_save_button, 20.0, 10.0)
	_save_button.disabled = true
	_save_button.pressed.connect(_on_save_pressed)
	button_row.add_child(_save_button)

	_retry_button = Button.new()
	_retry_button.text = "重新錄製"
	UiStyle.apply_wood_plaque_button(_retry_button, 20.0, 10.0)
	_retry_button.disabled = true
	_retry_button.pressed.connect(_on_retry_pressed)
	button_row.add_child(_retry_button)

	var back_button := Button.new()
	back_button.text = "← 返回"
	UiStyle.apply_wood_plaque_button(back_button, 20.0, 10.0)
	back_button.pressed.connect(func() -> void: back_requested.emit())
	button_row.add_child(back_button)

	_update_list_label()


func _on_start_pressed() -> void:
	_recorded_points.clear()
	_update_list_label()
	_start_button.disabled = true
	_save_button.disabled = true
	_retry_button.disabled = true
	_is_playing = true

	var bgm_path := RhythmChartStore.bgm_path_for(_building_type)
	if ResourceLoader.exists(bgm_path):
		_bgm_player.stream = load(bgm_path)
		if not _bgm_player.finished.is_connected(_on_bgm_finished):
			_bgm_player.finished.connect(_on_bgm_finished)
		_bgm_player.play()
	_clock.start()


func _on_bgm_finished() -> void:
	if _is_playing:
		_bgm_player.play()


func _process(_delta: float) -> void:
	if not _is_playing:
		return

	var t := _clock.elapsed()
	_progress_bar.value = clampf(t / DURATION_SEC, 0.0, 1.0) * 100.0

	if t >= DURATION_SEC:
		_finish_recording()


func _finish_recording() -> void:
	_is_playing = false
	_bgm_player.stop()
	_start_button.disabled = false
	_save_button.disabled = _recorded_points.is_empty()
	_retry_button.disabled = false


func _unhandled_input(event: InputEvent) -> void:
	if not _is_playing:
		return

	var is_tap: bool = (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE) \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if not is_tap:
		return

	var t := _clock.elapsed()
	if t > DURATION_SEC:
		return

	_recorded_points.append(t)
	_tap_sfx_player.stream = load(_hit_sfx_path)
	_tap_sfx_player.play()
	_update_list_label()


func _update_list_label() -> void:
	var text := "本次已記錄 %d 個斷點" % _recorded_points.size()
	if not _recorded_points.is_empty():
		var parts: Array[String] = []
		for point in _recorded_points:
			parts.append("%.2f" % point)
		text += "：" + ", ".join(PackedStringArray(parts))
	_list_label.text = text


func _on_save_pressed() -> void:
	RhythmChartStore.save_break_points(_building_type, _recorded_points)
	_existing_break_points = _recorded_points.duplicate()
	back_requested.emit()


func _on_retry_pressed() -> void:
	_recorded_points.clear()
	_update_list_label()
	_save_button.disabled = true
