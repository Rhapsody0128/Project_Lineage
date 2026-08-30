class_name RhythmChart
extends RefCounted

## 單一（生產）建築的節奏小遊戲譜面資料模型:提示譜(遊玩時提示音播放的時間點)+
## 玩家正確譜(判分基準的時間點),兩者都是「相對音樂開頭的秒數」時間戳陣列,由
## System/rhythm/rhythm_chart_store.gd 存讀成 JSON。純資料容器,不含任何播放/輸入邏輯
## ——那些需要碰 AudioStreamPlayer/Input 的部分屬於 Scenes 層(見 Scenes/RhythmGame/）。

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
