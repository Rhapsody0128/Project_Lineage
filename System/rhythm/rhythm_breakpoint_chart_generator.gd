class_name RhythmBreakpointChartGenerator
extends RefCounted

## 斷點式教學/應答譜面計算(RhythmBuildingPanel 的 F「斷點遊玩」用,見
## Scenes/RhythmGame/rhythm_play_view.gd 的 breakpoint_mode):不是憑空亂數生成音符,而是
## 「吃」設計者已經用 A 模式聽 BGM 錄好的真實提示譜(RhythmChartStore.load_chart(...).
## hint_beats,音符本來就落在真實音樂節奏上)當教學段內容的來源,只用計算的方式把每個教學段
## (奇數段)裡的提示譜音符,依「在該段內的相對比例位置(0~1)」等比例縮放對應到緊接著的應答段
## (偶數段)可用空間,算出玩家該打的正確譜——不會再有「生成音符沒卡在音樂節奏上」的問題,
## 因為教學段本身用的就是真人聽音樂打出來的真實時間戳,應答段只是照比例把同一個節奏形狀
## 搬過去,不是另外憑空亂數生一組。
##
## 斷點把 [0, RhythmChart.CHART_DURATION_SEC] 切成一段段,奇數段(第 1、3、5…段)是教學段、
## 偶數段(第 2、4、6…段)是應答段,兩兩配對;斷點總數是奇數、最後落單的教學段沒有配對
## 應答段時直接跳過(已知簡化)。同一組斷點+提示譜每次呼叫算出來的結果完全相同,不像先前
## 設計版本(純亂數生成)那樣每輪不同——先求音符準確卡在節奏上,不要求每輪隨機。

## 每一對(教學段/應答段)扣掉頭尾各留這麼多秒緩衝再拿來算,不讓落在斷點正上下的提示譜
## 音符被算進去,也不讓對應出來的正確譜音符貼著斷點。
const BOUNDARY_MARGIN := 0.6


## break_points:段落分界時間戳(見 RhythmChartStore.load_break_points())。
## source_hint_beats:當教學內容來源的真實提示譜(見 RhythmChartStore.load_chart(...).
## hint_beats),呼叫端決定要吃哪個 variant 的提示譜。
static func generate_hybrid(break_points: Array[float], source_hint_beats: Array[float]) -> RhythmChart:
	var chart := RhythmChart.new()

	var boundaries: Array[float] = [0.0]
	var sorted_points := break_points.duplicate()
	sorted_points.sort()
	for point in sorted_points:
		if point > 0.0 and point < RhythmChart.CHART_DURATION_SEC:
			boundaries.append(point)
	boundaries.append(RhythmChart.CHART_DURATION_SEC)

	var sorted_hint_beats := source_hint_beats.duplicate()
	sorted_hint_beats.sort()

	var segment_count := boundaries.size() - 1
	var i := 0
	while i + 1 < segment_count:
		var teach_lo: float = boundaries[i] + BOUNDARY_MARGIN
		var teach_hi: float = boundaries[i + 1] - BOUNDARY_MARGIN
		var player_lo: float = boundaries[i + 1] + BOUNDARY_MARGIN
		var player_hi: float = boundaries[i + 2] - BOUNDARY_MARGIN

		if teach_hi > teach_lo and player_hi > player_lo:
			var teach_span: float = teach_hi - teach_lo
			var player_span: float = player_hi - player_lo
			for note_time in sorted_hint_beats:
				if note_time < teach_lo or note_time > teach_hi:
					continue
				var fraction: float = (note_time - teach_lo) / teach_span
				chart.hint_beats.append(note_time)
				chart.correct_beats.append(player_lo + fraction * player_span)

		i += 2

	chart.hint_beats.sort()
	chart.correct_beats.sort()
	return chart
