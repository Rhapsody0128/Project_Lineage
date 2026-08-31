class_name RhythmGameTest
extends Control

## 節奏小遊戲測試場景(獨立於主遊戲流程,直接在編輯器對這個場景按 F6 執行）:12 個生產
## 建築的入口畫面 → 點選建築後先選常規版/變奏版(RhythmChartStore.VARIANT_REGULAR/
## VARIANT_VARIATION,見 RhythmBuildingPanel),再選 A(打提示譜)/B(打玩家正確譜)/
## C(觀看,播提示音)/D(遊玩,不播提示音)四顆按鈕 → RhythmRecordView(A/B 共用)或
## RhythmPlayView(C/D 共用,差別只在 play_hint_sfx 旗標),都吃選定的 variant 字串,讀寫
## 對應版本的譜面。玩法定案、素材做好後再嵌入 Scenes/Base 的根據地生產建築面板,不在這裡
## 處理跟根據地系統的整合。
##
## BgmPlayer/HintSfxPlayer/TapSfxPlayer 三個 AudioStreamPlayer 常駐在根節點,傳給每個子
## 畫面共用,避免每次切換畫面都新增/釋放播放器節點。

@onready var _content_root: Control = $Root
@onready var _title_label: Label = $Title
@onready var _bgm_player: AudioStreamPlayer = $BgmPlayer
@onready var _hint_sfx_player: AudioStreamPlayer = $HintSfxPlayer
@onready var _tap_sfx_player: AudioStreamPlayer = $TapSfxPlayer


func _ready() -> void:
	_show_building_select()


func _show_building_select() -> void:
	_title_label.text = "節奏小遊戲測試"
	_clear_content()

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	grid.set_anchors_preset(Control.PRESET_CENTER)
	_content_root.add_child(grid)

	for building in BuildingLibrary.get_all():
		if not building.is_production_building():
			continue
		var button := Button.new()
		button.text = building.name
		button.custom_minimum_size = Vector2(160, 80)
		UiStyle.apply_wood_plaque_button(button, 16.0, 10.0)
		var building_type := building.type
		button.pressed.connect(func() -> void: _show_building_panel(building_type))
		grid.add_child(button)


func _show_building_panel(building_type: GameEnums.BuildingType) -> void:
	_title_label.text = "%s・節奏小遊戲" % GameEnums.BUILDING_TYPE_LABELS[building_type]
	_clear_content()

	var panel := RhythmBuildingPanel.new()
	panel.setup(building_type)
	panel.back_requested.connect(_show_building_select)
	panel.record_hint_requested.connect(
		func(variant: String) -> void: _start_record(building_type, true, variant)
	)
	panel.record_correct_requested.connect(
		func(variant: String) -> void: _start_record(building_type, false, variant)
	)
	panel.watch_requested.connect(
		func(variant: String) -> void: _start_play(building_type, variant, true)
	)
	panel.play_requested.connect(
		func(variant: String) -> void: _start_play(building_type, variant, false)
	)
	_content_root.add_child(panel)


func _start_record(building_type: GameEnums.BuildingType, is_hint_mode: bool, variant: String) -> void:
	_clear_content()

	var view := RhythmRecordView.new()
	view.setup(building_type, is_hint_mode, variant, _bgm_player, _hint_sfx_player, _tap_sfx_player)
	view.back_requested.connect(func() -> void: _show_building_panel(building_type))
	_content_root.add_child(view)


func _start_play(building_type: GameEnums.BuildingType, variant: String, play_hint_sfx: bool) -> void:
	_clear_content()

	var view := RhythmPlayView.new()
	view.setup(building_type, variant, play_hint_sfx, _bgm_player, _hint_sfx_player, _tap_sfx_player)
	view.back_requested.connect(func() -> void: _show_building_panel(building_type))
	_content_root.add_child(view)


func _clear_content() -> void:
	_bgm_player.stop()
	for child in _content_root.get_children():
		child.queue_free()
