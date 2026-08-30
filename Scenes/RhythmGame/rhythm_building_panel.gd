class_name RhythmBuildingPanel
extends Control

## 選定單一生產建築後的三顆模式按鈕(A 打提示譜/B 打玩家正確譜/C 測試),見
## rhythm_game_test.gd 的 _show_building_panel()。純畫面,不含錄製/測試邏輯本身
## ——那些各自在 RhythmRecordView/RhythmPlayView。

signal back_requested
signal record_hint_requested
signal record_correct_requested
signal test_requested

var _building_type: GameEnums.BuildingType = -1
var _status_label: Label


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

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 16)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_status_label)

	column.add_child(_make_button("A　打提示譜", func() -> void: record_hint_requested.emit()))
	column.add_child(_make_button("B　打玩家正確譜", func() -> void: record_correct_requested.emit()))
	column.add_child(_make_button("C　測試", func() -> void: test_requested.emit()))
	column.add_child(_make_button("← 返回建築列表", func() -> void: back_requested.emit()))


func _make_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(280, 60)
	UiStyle.apply_wood_plaque_button(button, 20.0, 12.0)
	button.pressed.connect(callback)
	return button


func _refresh_status() -> void:
	var chart := RhythmChartStore.load_chart(_building_type)
	_status_label.text = "提示譜音符數：%d　玩家正確譜音符數：%d" % [chart.hint_beats.size(), chart.correct_beats.size()]
