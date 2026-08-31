class_name RhythmChart
extends RefCounted

## 單一（生產）建築、單一版本(RhythmChartStore.VARIANT_REGULAR/VARIANT_VARIATION)的
## 節奏小遊戲譜面資料模型:提示譜(遊玩時提示音播放的時間點)+ 玩家正確譜(判分基準的
## 時間點),兩者都是「相對音樂開頭的秒數」時間戳陣列。一個建築的 JSON 檔內同時存兩個
## 版本各一份這個結構(見 System/rhythm/rhythm_chart_store.gd 的巢狀 variant 存讀),這裡
## 只負責單一版本的資料容器,不含任何播放/輸入邏輯——那些需要碰 AudioStreamPlayer/Input
## 的部分屬於 Scenes 層(見 Scenes/RhythmGame/）。

## 小遊戲總長度,對應正式 BGM 素材的長度(見 RhythmChartStore.bgm_path_for())。
const CHART_DURATION_SEC := 60.0

var hint_beats: Array[float] = []
var correct_beats: Array[float] = []


func to_dict() -> Dictionary:
	return {"hint_beats": hint_beats, "correct_beats": correct_beats}


static func from_dict(data: Dictionary) -> RhythmChart:
	var chart := RhythmChart.new()
	if data.has("hint_beats"):
		for value in data["hint_beats"]:
			chart.hint_beats.append(float(value))
	if data.has("correct_beats"):
		for value in data["correct_beats"]:
			chart.correct_beats.append(float(value))
	return chart
