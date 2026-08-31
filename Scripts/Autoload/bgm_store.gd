extends Node

# =========================================================
# 全域場景背景音樂(autoload,見 project.godot)。MAP/BATTLE 兩個場景各自在 _ready()
# 呼叫 play_map()/play_battle() 開始播放對應 BGM,離開場景時(_exit_tree)呼叫
# fade_out() 淡出——不直接 stop(),避免音樂被瞬間切斷的割裂感。曲目本身 loop=false
# (見 .mp3.import),播到快結束時同樣淡出接淡入從頭重播,取代硬切點造成的割裂感,
# 效果等同無縫循環。離開場景時會記住播到哪一秒(_resume_positions),下次切回同一首
# 曲子從中斷處接著淡入,不會每次都重頭放。
# =========================================================

const FADE_DURATION := 1.5
## 曲目播放到只剩這麼多秒時開始淡出、準備回頭重播,取代 AudioStreamPlayer 播放到底
## 瞬間跳回開頭的硬切點。
const LOOP_FADE_LEAD := 2.0
const SILENT_VOLUME_DB := -40.0

const MAP_BGM: AudioStream = preload("res://Sound/Map/BGM/Map.mp3")
const BATTLE_BGM: AudioStream = preload("res://Sound/Battle/BGM/Battle.mp3")

var _player: AudioStreamPlayer
var _fade_tween: Tween
var _current_stream: AudioStream
## 目前是否處於「該場景仍在播放」狀態——true 時 _process() 才會盯著播放進度準備
## 淡出重播;fade_out() 會把它關掉,讓已經在跑的淡出/淡入不會被當成快循環完畢又觸發一次。
var _looping := false
## AudioStream -> 上次 fade_out() 當下播放到的秒數,同一首曲子下次 _play() 時從這裡
## 接著播(而不是從頭),讓玩家離開又切回來(例如大地圖進出建築面板)時音樂接得上,
## 不會每次都從頭放。只存在記憶體裡,不隨存檔保存——重開遊戲就重新從頭起算。
var _resume_positions: Dictionary = {}


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_player.finished.connect(_on_player_finished)


func _process(_delta: float) -> void:
	if not _looping or not _player.playing or _player.stream == null:
		return
	var length := _player.stream.get_length()
	if length <= 0.0:
		return
	if _player.get_playback_position() >= length - LOOP_FADE_LEAD and (_fade_tween == null or not _fade_tween.is_valid()):
		_start_loop_fade()


func play_map() -> void:
	_play(MAP_BGM)


func play_battle() -> void:
	_play(BATTLE_BGM)


## 場景離開時呼叫(見 Scenes/Map/map.gd、Scenes/Battle/battle.gd 的 _exit_tree())。
## 淡出後才真正 stop(),避免下個場景聽到殘留的音量瞬間掉為零。離開當下先記住目前播到
## 哪一秒(_resume_positions),下次同一首曲子 _play() 時就從這裡接著放。
func fade_out() -> void:
	if _player.playing and _current_stream != null:
		_resume_positions[_current_stream] = _player.get_playback_position()
	_looping = false
	_current_stream = null
	if not _player.playing:
		return
	_kill_fade_tween()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_player, "volume_db", SILENT_VOLUME_DB, FADE_DURATION)
	_fade_tween.tween_callback(_player.stop)


func _play(stream: AudioStream) -> void:
	if _current_stream == stream and _player.playing:
		return
	_kill_fade_tween()
	_current_stream = stream
	_looping = true
	_player.stream = stream
	_player.volume_db = SILENT_VOLUME_DB
	_player.play(_resume_positions.get(stream, 0.0))
	_fade_tween = create_tween()
	_fade_tween.tween_property(_player, "volume_db", 0.0, FADE_DURATION)


func _start_loop_fade() -> void:
	_kill_fade_tween()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_player, "volume_db", SILENT_VOLUME_DB, LOOP_FADE_LEAD)
	_fade_tween.tween_callback(_restart_loop)


func _restart_loop() -> void:
	if not _looping:
		return
	_player.play(0.0)
	_fade_tween = create_tween()
	_fade_tween.tween_property(_player, "volume_db", 0.0, FADE_DURATION)


## 保險 fallback:萬一 _process() 沒能在曲末前及時攔到(掉幀等），播放器自然播完時
## 一樣視同循環點,直接重播,不會冷不防陷入靜音。
func _on_player_finished() -> void:
	if _looping:
		_restart_loop()


func _kill_fade_tween() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
