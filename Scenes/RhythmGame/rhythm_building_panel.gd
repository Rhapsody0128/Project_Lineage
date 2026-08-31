class_name RhythmBuildingPanel
extends Control

## 選定單一生產建築後的版本切換（常規版/變奏版）+ 四顆模式按鈕（A 打提示譜/B 打玩家
## 正確譜/C 觀看/D 遊玩），見 rhythm_game_test.gd 的 _show_building_panel()。純畫面,不含
## 錄製/試玩邏輯本身——那些各自在 RhythmRecordView/RhythmPlayView。C 觀看會播提示音效,
## 提示音精準對在正確拍上等於直接唸答案,適合設計者核對譜面本身對不對;D 遊玩不播提示音,
## 只放 BGM 讓玩家自己聽音樂打拍,才是實際上線後的體驗,兩者共用同一份 RhythmPlayView,
## 差別只在 play_hint_sfx 旗標。四個 signal 都帶目前選定的 variant 字串
## （RhythmChartStore.VARIANT_REGULAR/VARIANT_VARIATION）,呼叫端據此決定要錄製/試玩
## 哪一份譜面。

signal back_requested
signal record_hint_requested(variant: String)
signal record_correct_requested(variant: String)
signal watch_requested(variant: String)
signal play_requested(variant: String)

const _VARIANT_LABELS := {
	RhythmChartStore.VARIANT_REGULAR: "常規版",
	RhythmChartStore.VARIANT_VARIATION: "變奏版",
}

var _building_type: GameEnums.BuildingType = -1
var _variant: String = RhythmChartStore.VARIANT_REGULAR
var _status_label: Label
var _variant_buttons: Dictionary = {}


func setup(building_type: GameEnums.BuildingType) -> void:
	_building_type = building_type
	_build_layout()
	_refresh_status()


func _build_layout() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(column)

	var variant_row := HBoxContainer.new()
	variant_row.add_theme_constant_override("separation", 8)
	variant_row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(variant_row)

	var variant_group := ButtonGroup.new()
	for variant in RhythmChartStore.VARIANTS:
		var button := Button.new()
		button.text = _VARIANT_LABELS[variant]
		button.toggle_mode = true
		button.button_group = variant_group
		button.button_pressed = variant == _variant
		button.custom_minimum_size = Vector2(120, 44)
		UiStyle.apply_wood_plaque_button(button, 16.0, 8.0)
		button.pressed.connect(func() -> void: _on_variant_selected(variant))
		variant_row.add_child(button)
		_variant_buttons[variant] = button

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 16)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_status_label)

	column.add_child(_make_button("A　打提示譜", func() -> void: record_hint_requested.emit(_variant)))
	column.add_child(_make_button("B　打玩家正確譜", func() -> void: record_correct_requested.emit(_variant)))
	column.add_child(_make_button("C　觀看（播提示音）", func() -> void: watch_requested.emit(_variant)))
	column.add_child(_make_button("D　遊玩（不播提示音）", func() -> void: play_requested.emit(_variant)))
	column.add_child(_make_button("← 返回建築列表", func() -> void: back_requested.emit()))


func _make_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(280, 60)
	UiStyle.apply_wood_plaque_button(button, 20.0, 12.0)
	button.pressed.connect(callback)
	return button


func _on_variant_selected(variant: String) -> void:
	_variant = variant
	_refresh_status()


func _refresh_status() -> void:
	var chart := RhythmChartStore.load_chart(_building_type, _variant)
	_status_label.text = "%s　提示譜音符數：%d　玩家正確譜音符數：%d" % [
		_VARIANT_LABELS[_variant], chart.hint_beats.size(), chart.correct_beats.size()
	]
