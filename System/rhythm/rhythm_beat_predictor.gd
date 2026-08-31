class_name RhythmBeatPredictor
extends RefCounted

## 節奏預測圈的縮圈比例計算(RhythmPlayView 沒有設計角色動作圖的建築改顯示這個,見
## Scenes/RhythmGame/rhythm_beat_indicator.gd 的繪製邏輯):固定圓+等速縮小圓,每個正確譜
## 節點各自在節點前 LEAD_TIME 秒出現一顆縮小圓,之後等速縮小,縮到節點時間點當下正好跟
## 固定圓疊合——玩家在兩圓重合當下按下即為 PERFECT 時間點。連打段落(多個節點間隔小於
## LEAD_TIME)會同時有多顆縮小圓並存,各自獨立縮小,不是只顯示最近的一顆。純函式,只算
## 「縮小圓相對固定圓的縮放比例」,不碰任何 Node/畫圖。

const LEAD_TIME := 1.0
## 節點時間點過後再讓縮小圓貼著固定圓多停留一小段時間,避免命中瞬間畫面直接消失。
const LINGER_TIME := 0.15


## 回傳目前該顯示的所有縮圈比例(每個元素 0~1,0 代表剛出現的最大圈,1 代表跟固定圓完全
## 重合的正確時間點),對應每個「離最近節點還很遠或已超過停留時間」以外的節點——一個節點
## 一個獨立比例,連打時會回傳多個,不合併成一顆。回傳陣列為空代表這個時間點沒有任何該顯示
## 的縮圈。beats 不要求已排序。
static func active_fractions_for(t: float, beats: Array[float]) -> Array[float]:
	var fractions: Array[float] = []
	for beat in beats:
		var time_until: float = beat - t
		if time_until > LEAD_TIME or time_until < -LINGER_TIME:
			continue
		var fraction: float = 1.0 if time_until <= 0.0 else 1.0 - time_until / LEAD_TIME
		fractions.append(fraction)
	return fractions
