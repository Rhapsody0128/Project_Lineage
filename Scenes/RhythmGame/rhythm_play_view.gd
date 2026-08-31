class_name RhythmPlayView
extends Control

## C(觀看)/D(遊玩)共用的試玩畫面。播放 BGM(依建築查專屬素材,見
## RhythmChartStore.bgm_path_for()),玩家按 Space 或滑鼠左鍵打拍子。每次點擊當下立刻用
## RhythmScorer.judge() 對「誤差最小、還沒配對過」的正確譜音符給出 PERFECT/GREAT/GOOD/MISS
## 即時判定(見 _judge_tap()),同步更新旁邊的累計分數;結束後另外呼叫 RhythmScorer.score()
## 算一次最終總分——那個是事後批次比對,會額外把「玩家完全沒點到」的音符算進 MISS,即時
## 判定當下看不到那種漏拍,兩者非同一份配對結果、數字可能有些微落差是正常的。variant
## (RhythmChartStore.VARIANT_REGULAR/VARIANT_VARIATION)決定測試哪一份版本的譜面,由
## 呼叫端(RhythmBuildingPanel)選定後傳入。
##
## play_hint_sfx 控制要不要在提示譜(hint_beats)的時間點播放提示音效:C(觀看)開啟——
## 提示音精準對在玩家正確譜同一拍上,等於直接把答案唸出來,適合設計者核對譜面本身對不對,
## 不適合拿來測「聽音樂打拍子」的真實手感;D(遊玩)關閉,只播 BGM,玩家得自己聽音樂打拍,
## 才是實際上線後玩家會遇到的體驗——兩者共用同一份判定/計分邏輯,差別只在要不要播這個
## 音效提示。

signal back_requested

const DURATION_SEC := RhythmChart.CHART_DURATION_SEC
## 提示音/點擊音效改用 RhythmChartStore.hit_sfx_path_for(building_type) 依建築查專屬
## 特效音(res://Sound/Base/hit/<建築>.mp3),取代舊版全建築共用的暫代 hint.mp3。
## BGM 同樣用 RhythmChartStore.bgm_path_for(building_type) 依建築查專屬素材。

const _JUDGEMENT_COLORS := {
	"PERFECT": Color(1.0, 0.85, 0.2),
	"GREAT": Color(0.55, 0.9, 0.5),
	"GOOD": Color(0.55, 0.75, 1.0),
	"MISS": Color(0.9, 0.35, 0.35),
}

## RhythmCharacterState 可能用到的所有狀態,對應 RhythmChartStore.sprite_path_for() 要找的
## <建築>/HOLD.png 等圖——逐一嘗試載入,缺的就跳過,不是「少一張就整包放棄」,見
## _load_character_textures() 的最低需求判斷。
const _CHARACTER_STATE_CANDIDATES := [
	RhythmCharacterState.HOLD, RhythmCharacterState.HOLD2,
	RhythmCharacterState.HINT, RhythmCharacterState.HINT1, RhythmCharacterState.HINT2,
	RhythmCharacterState.HIT, RhythmCharacterState.FIN, RhythmCharacterState.FAIL,
]

var _building_type: GameEnums.BuildingType = -1
var _variant: String = RhythmChartStore.VARIANT_REGULAR
var _play_hint_sfx: bool = true
var _bgm_player: AudioStreamPlayer
var _hint_sfx_player: AudioStreamPlayer
var _tap_sfx_player: AudioStreamPlayer
var _hit_sfx_path: String = ""

var _chart: RhythmChart
var _player_taps: Array[float] = []
var _next_hint_index := 0
var _is_playing := false
var _clock := RhythmClock.new()

## 即時判定用:排序後的正確譜 + 是否已被某次點擊配對走,跟 RhythmScorer.score() 內部
## 邏輯相同,只是這裡逐次累加而不是事後一次算完。
var _sorted_correct_beats: Array[float] = []
var _correct_beat_used: Array[bool] = []
var _judged_count := 0
var _score_sum := 0.0

var _progress_bar: ProgressBar
var _tap_count_label: Label
var _judgement_label: Label
var _score_label: Label
var _result_label: Label
var _start_button: Button

## 下方角色動作圖輪播(見 RhythmCharacterState),用玩家正確譜(correct_beats)驅動,
## 不是提示音的時間戳。_character_textures 為空代表這個建築缺素材,整塊直接不顯示。
var _character_rect: TextureRect
var _character_textures: Dictionary = {}
var _current_character_state: String = ""
## 玩家敲 MISS 當下覆蓋顯示 FAIL 到這個時間點為止(_clock.elapsed() 的秒數),平常是
## -INF(永遠不觸發)。見 _judge_tap()/_update_character_state()。
var _fail_display_until := -INF

## 缺角色動作圖素材的建築改顯示節奏預測圈(見 RhythmBeatIndicator),同樣用玩家正確譜
## 驅動。_character_textures 非空時 _beat_indicator 維持 null,不建立這塊區域。
var _beat_indicator: RhythmBeatIndicator


func setup(
	building_type: GameEnums.BuildingType,
	variant: String,
	play_hint_sfx: bool,
	bgm_player: AudioStreamPlayer,
	hint_sfx_player: AudioStreamPlayer,
	tap_sfx_player: AudioStreamPlayer
) -> void:
	_building_type = building_type
	_variant = variant
	_play_hint_sfx = play_hint_sfx
	_bgm_player = bgm_player
	_hint_sfx_player = hint_sfx_player
	_tap_sfx_player = tap_sfx_player
	_hit_sfx_path = RhythmChartStore.hit_sfx_path_for(building_type)
	_chart = RhythmChartStore.load_chart(building_type, _variant)
	_sorted_correct_beats = _chart.correct_beats.duplicate()
	_sorted_correct_beats.sort()
	_load_character_textures()
	_build_layout()


## 逐一嘗試載入每張候選圖,缺的就跳過(不同建築素材組合不一定一致,例如只有一張 HOLD、
## 沒有 HOLD2,或提示圖拆成 HINT1+HINT2 兩張,見 RhythmCharacterState 檔頭註解)。最低需求
## 是 HOLD/HIT/FIN 都在,加上 HINT 或(HINT1+HINT2)擇一——這三者缺一就視為這個建築還沒
## 做動作素材,_character_textures 清空,_build_layout() 依此隱藏整塊區域。HOLD2/FAIL純粹
## 是可選加分項。
func _load_character_textures() -> void:
	_character_textures.clear()
	for state in _CHARACTER_STATE_CANDIDATES:
		var path := RhythmChartStore.sprite_path_for(_building_type, state)
		if ResourceLoader.exists(path):
			_character_textures[state] = load(path)

	var has_hint: bool = _character_textures.has(RhythmCharacterState.HINT) or (
		_character_textures.has(RhythmCharacterState.HINT1)
		and _character_textures.has(RhythmCharacterState.HINT2)
	)
	var has_required: bool = _character_textures.has(RhythmCharacterState.HOLD) \
		and _character_textures.has(RhythmCharacterState.HIT) \
		and _character_textures.has(RhythmCharacterState.FIN) \
		and has_hint
	if not has_required:
		_character_textures.clear()


func _build_layout() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 12)
	add_child(column)

	var variant_label := "常規版" if _variant == RhythmChartStore.VARIANT_REGULAR else "變奏版"
	var mode_label := "觀看（播提示音）" if _play_hint_sfx else "遊玩（不播提示音）"
	var title := Label.new()
	title.text = "%s：%s・Space 或滑鼠左鍵打拍子，共 %.0f 秒" % [mode_label, variant_label, DURATION_SEC]
	title.add_theme_font_size_override("font_size", 20)
	column.add_child(title)

	_progress_bar = ProgressBar.new()
	_progress_bar.max_value = 100.0
	_progress_bar.value = 0.0
	column.add_child(_progress_bar)

	_tap_count_label = Label.new()
	_tap_count_label.text = "已點擊 0 次"
	column.add_child(_tap_count_label)

	var live_row := HBoxContainer.new()
	live_row.add_theme_constant_override("separation", 20)
	column.add_child(live_row)

	_judgement_label = Label.new()
	_judgement_label.add_theme_font_size_override("font_size", 32)
	live_row.add_child(_judgement_label)

	_score_label = Label.new()
	_score_label.text = "目前分數：0.0"
	_score_label.add_theme_font_size_override("font_size", 22)
	live_row.add_child(_score_label)

	_result_label = Label.new()
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_result_label.add_theme_font_size_override("font_size", 18)
	column.add_child(_result_label)

	if not _character_textures.is_empty():
		_character_rect = TextureRect.new()
		_character_rect.custom_minimum_size = Vector2(200, 200)
		_character_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		_character_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_character_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_character_rect.texture = _character_textures[RhythmCharacterState.HOLD]
		column.add_child(_character_rect)
	else:
		_beat_indicator = RhythmBeatIndicator.new()
		_beat_indicator.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(_beat_indicator)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 12)
	column.add_child(button_row)

	_start_button = Button.new()
	_start_button.text = "開始"
	UiStyle.apply_wood_plaque_button(_start_button, 20.0, 10.0)
	_start_button.pressed.connect(_on_start_pressed)
	button_row.add_child(_start_button)

	var back_button := Button.new()
	back_button.text = "← 返回"
	UiStyle.apply_wood_plaque_button(back_button, 20.0, 10.0)
	back_button.pressed.connect(func() -> void: back_requested.emit())
	button_row.add_child(back_button)

	if _chart.correct_beats.is_empty():
		_result_label.text = "這個建築還沒有玩家正確譜，請先用 B 模式錄製。"
		_start_button.disabled = true


func _on_start_pressed() -> void:
	_player_taps.clear()
	_next_hint_index = 0
	_result_label.text = ""
	_tap_count_label.text = "已點擊 0 次"
	_judgement_label.text = ""
	_score_label.text = "目前分數：0.0"
	_start_button.disabled = true
	_is_playing = true

	_correct_beat_used.resize(_sorted_correct_beats.size())
	_correct_beat_used.fill(false)
	_judged_count = 0
	_score_sum = 0.0
	_current_character_state = ""

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

	while _next_hint_index < _chart.hint_beats.size() and _chart.hint_beats[_next_hint_index] <= t:
		if _play_hint_sfx:
			_hint_sfx_player.stream = load(_hit_sfx_path)
			_hint_sfx_player.play()
		_next_hint_index += 1

	_update_character_state(t)
	if _beat_indicator != null:
		_beat_indicator.update_time(t, _sorted_correct_beats)

	if t >= DURATION_SEC:
		_finish_test()


func _update_character_state(t: float) -> void:
	if _character_textures.is_empty():
		return
	## FAIL 覆蓋期間內不用正常的時間軸邏輯算狀態,見 _judge_tap()。
	if t < _fail_display_until:
		return
	var state := RhythmCharacterState.state_for(t, _sorted_correct_beats, _character_textures)
	if state == _current_character_state:
		return
	_current_character_state = state
	_character_rect.texture = _character_textures[state]


func _finish_test() -> void:
	_is_playing = false
	_bgm_player.stop()
	_start_button.disabled = false

	var result := RhythmScorer.score(_chart.correct_beats, _player_taps)
	_result_label.text = "最終分數：%.1f 分　命中 %d / %d，MISS %d" % [
		result["average"], result["hit_count"], result["note_count"], result["miss_count"]
	]


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

	_player_taps.append(t)
	_tap_count_label.text = "已點擊 %d 次" % _player_taps.size()
	_tap_sfx_player.stream = load(_hit_sfx_path)
	_tap_sfx_player.play()

	_judge_tap(t)


## 從還沒被配對走的正確譜音符裡找誤差最小的一個(超過 RhythmScorer.MISS_WINDOW 不算),
## 立刻顯示判定文字並累加分數——跟 RhythmScorer.score() 同一套「誤差最小者優先」配對邏輯,
## 差別只在這裡逐次呼叫、事後才批次算一次。
func _judge_tap(t: float) -> void:
	var best_index := -1
	var best_diff := INF
	for i in _sorted_correct_beats.size():
		if _correct_beat_used[i]:
			continue
		var diff: float = absf(_sorted_correct_beats[i] - t)
		if diff <= RhythmScorer.MISS_WINDOW and diff < best_diff:
			best_diff = diff
			best_index = i

	var judgement: String = RhythmScorer.judge(best_diff) if best_index != -1 else RhythmScorer.JUDGEMENT_MISS
	if best_index != -1:
		_correct_beat_used[best_index] = true

	_judgement_label.text = judgement
	_judgement_label.add_theme_color_override("font_color", _JUDGEMENT_COLORS[judgement])

	## 缺 FAIL 素材的建築(例如 LUMBER_MILL)維持舊行為,不對 MISS 做任何動作圖反應。
	if judgement == RhythmScorer.JUDGEMENT_MISS and _character_textures.has(RhythmCharacterState.FAIL):
		_fail_display_until = t + RhythmCharacterState.HIT_HOLD_DURATION
		_current_character_state = RhythmCharacterState.FAIL
		_character_rect.texture = _character_textures[RhythmCharacterState.FAIL]

	_judged_count += 1
	_score_sum += RhythmScorer.POINTS_BY_JUDGEMENT[judgement] as float
	_score_label.text = "目前分數：%.1f" % (_score_sum / _judged_count)
