class_name RhythmClock
extends RefCounted

## 節奏小遊戲的計時基準:用引擎單調時鐘(Time.get_ticks_usec())算經過秒數,故意不綁定
## AudioStreamPlayer.playback_position——測試階段的 BGM 只是任意長度的暫代音效,靠
## `finished` 訊號手動重播撐滿整段小遊戲時長(見 Scenes/RhythmGame/），播放位置會在每次
## 重播時歸零,不能拿來當累積經過時間的基準,必須自己維護一條獨立時間軸。

var _start_usec: int = 0


func start() -> void:
	_start_usec = Time.get_ticks_usec()


func elapsed() -> float:
	return (Time.get_ticks_usec() - _start_usec) / 1_000_000.0
