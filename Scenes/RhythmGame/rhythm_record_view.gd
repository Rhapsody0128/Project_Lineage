class_name RhythmRecordView
extends Control

## A/B 模式共用的「錄製譜面」畫面:播放 BGM(+ B 模式額外播放既有提示譜的提示音),玩家
## (此處即設計者本人)按 Space 或滑鼠左鍵打拍子,系統記錄當下時間戳,結束後存檔。
## A 模式(is_hint_mode=true)只播 BGM,錄下的時間戳存成提示譜;B 模式額外播放已存的
## 提示譜提示音當參考,錄下的時間戳存成玩家正確譜——兩模式共用同一套「播放+記錄」邏輯,
## 差別只在要不要播提示音、存檔存去哪個欄位。variant(RhythmChartStore.VARIANT_REGULAR/
## VARIANT_VARIATION)決定讀寫哪一份版本的譜面,由呼叫端(RhythmBuildingPanel)選定後傳入。

signal back_requested

const DURATION_SEC := RhythmChart.CHART_DURATION_SEC
## 提示音/點擊音效改用 RhythmChartStore.hit_sfx_path_for(building_type) 依建築查專屬
## 特效音(res://Sound/Base/hit/<建築>.mp3),取代舊版全建築共用的暫代 hint.mp3。
## BGM 同樣用 RhythmChartStore.bgm_path_for(building_type) 依建築查專屬素材。

var _building_type: GameEnums.BuildingType = -1
var _is_hint_mode: bool = true
var _variant: String = RhythmChartStore.VARIANT_REGULAR
var _bgm_player: AudioStreamPlayer
var _hint_sfx_player: AudioStreamPlayer
var _tap_sfx_player: AudioStreamPlayer
var _hit_sfx_path: String = ""

var _hint_beats: Array[float] = []
var _recorded_beats: Array[float] = []
var _next_hint_index := 0
var _is_playing := false
var _clock := RhythmClock.new()

var _progress_bar: ProgressBar
var _list_label: Label
var _start_button: Button
var _save_button: Button
var _retry_button: Button


func setup(
	building_type: GameEnums.BuildingType,
	is_hint_mode: bool,
	variant: String,
	bgm_player: AudioStreamPlayer,
	hint_sfx_player: AudioStreamPlayer,
	tap_sfx_player: AudioStreamPlayer
) -> void:
	_building_type = building_type
	_is_hint_mode = is_hint_mode
	_variant = variant
	_bgm_player = bgm_player
	_hint_sfx_player = hint_sfx_player
	_tap_sfx_player = tap_sfx_player
	_hit_sfx_path = RhythmChartStore.hit_sfx_path_for(building_type)
	if not _is_hint_mode:
		_hint_beats = RhythmChartStore.load_chart(building_type, _variant).hint_beats.duplicate()
	_build_layout()


func _build_layout() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 12)
	add_child(column)

	var variant_label := "常規版" if _variant == RhythmChartStore.VARIANT_REGULAR else "變奏版"
	var title := Label.new()
	title.text = "正在錄製：%s・%s（Space 或滑鼠左鍵打拍子，共 %.0f 秒）" % [
		variant_label, "提示譜" if _is_hint_mode else "玩家正確譜", DURATION_SEC
	]
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
	_recorded_beats.clear()
	_next_hint_index = 0
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

	if not _is_hint_mode:
		while _next_hint_index < _hint_beats.size() and _hint_beats[_next_hint_index] <= t:
			_hint_sfx_player.stream = load(_hit_sfx_path)
			_hint_sfx_player.play()
			_next_hint_index += 1

	if t >= DURATION_SEC:
		_finish_recording()


func _finish_recording() -> void:
	_is_playing = false
	_bgm_player.stop()
	_start_button.disabled = false
	_save_button.disabled = _recorded_beats.is_empty()
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

	_recorded_beats.append(t)
	_tap_sfx_player.stream = load(_hit_sfx_path)
	_tap_sfx_player.play()
	_update_list_label()


func _update_list_label() -> void:
	var text := "已記錄 %d 個節點" % _recorded_beats.size()
	if not _recorded_beats.is_empty():
		var parts: Array[String] = []
		for beat in _recorded_beats:
			parts.append("%.2f" % beat)
		text += "：" + ", ".join(PackedStringArray(parts))
	_list_label.text = text


func _on_save_pressed() -> void:
	if _is_hint_mode:
		RhythmChartStore.save_hint_beats(_building_type, _variant, _recorded_beats)
	else:
		RhythmChartStore.save_correct_beats(_building_type, _variant, _recorded_beats)
	back_requested.emit()


func _on_retry_pressed() -> void:
	_recorded_beats.clear()
	_next_hint_index = 0
	_update_list_label()
	_save_button.disabled = true
