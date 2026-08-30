class_name RhythmScorer
extends RefCounted

## 節奏小遊戲判分:對玩家正確譜(correct_beats)裡的每個音符,從玩家實際點擊
## (player_taps)裡找一個「誤差最小、還沒被配對過」的點擊,依誤差落在哪個判定帶給分
## ——PERFECT/GREAT/GOOD/MISS 四級(見下方 WINDOW 常數與 judge())。找不到可配對的點擊
## (誤差超過 MISS_WINDOW,或該音符附近的點擊都已被更早的音符搶走)一律算 MISS。多餘、
## 配對不到任何音符的點擊不計分也不扣分。
##
## judge()/POINTS_BY_JUDGEMENT 額外開放給 Scenes/RhythmGame/rhythm_play_view.gd 在玩家
## 每次點擊當下即時判定用(見該檔 _judge_tap()),跟這裡 score() 事後批次算總分用的是
## 同一套誤差帶,只是即時判定只看「這一擊」,不像 score() 會反過來檢查有沴音符完全沒被
## 打到(那種只有事後才看得出來,即時判定當下不存在對應的「這一擊」)。

const PERFECT_WINDOW := 0.01
const GREAT_WINDOW := 0.05
const GOOD_WINDOW := 0.1
## 超過這個誤差視同完全配對不到,跟找不到點擊的 MISS 是同一種結果。
const MISS_WINDOW := 0.2

const JUDGEMENT_PERFECT := "PERFECT"
const JUDGEMENT_GREAT := "GREAT"
const JUDGEMENT_GOOD := "GOOD"
const JUDGEMENT_MISS := "MISS"

const POINTS_BY_JUDGEMENT := {
	JUDGEMENT_PERFECT: 100.0,
	JUDGEMENT_GREAT: 80.0,
	JUDGEMENT_GOOD: 50.0,
	JUDGEMENT_MISS: 0.0,
}


## 依誤差(秒,絕對值)判斷落在哪個判定帶,誤差超過 MISS_WINDOW 一律回傳 MISS。
static func judge(abs_diff: float) -> String:
	if abs_diff <= PERFECT_WINDOW:
		return JUDGEMENT_PERFECT
	if abs_diff <= GREAT_WINDOW:
		return JUDGEMENT_GREAT
	if abs_diff <= GOOD_WINDOW:
		return JUDGEMENT_GOOD
	return JUDGEMENT_MISS


## 回傳 {"note_scores"/"note_judgements": 每個音符的得分/判定陣列(順序對應排序後的
## correct_beats), "average": 平均分數(0~100), "hit_count": 非 MISS 音符數,
## "miss_count": MISS 音符數, "note_count": 正確譜音符總數}。
static func score(correct_beats: Array[float], player_taps: Array[float]) -> Dictionary:
	var sorted_beats := correct_beats.duplicate()
	sorted_beats.sort()
	var sorted_taps := player_taps.duplicate()
	sorted_taps.sort()

	var used: Array[bool] = []
	used.resize(sorted_taps.size())
	used.fill(false)

	var note_scores: Array[float] = []
	var note_judgements: Array[String] = []
	var hit_count := 0

	for beat in sorted_beats:
		var best_index := -1
		var best_diff := INF
		for i in sorted_taps.size():
			if used[i]:
				continue
			var diff: float = absf(sorted_taps[i] - beat)
			if diff <= MISS_WINDOW and diff < best_diff:
				best_diff = diff
				best_index = i

		var judgement := judge(best_diff) if best_index != -1 else JUDGEMENT_MISS
		note_judgements.append(judgement)
		note_scores.append(POINTS_BY_JUDGEMENT[judgement] as float)
		if best_index != -1:
			used[best_index] = true
		if judgement != JUDGEMENT_MISS:
			hit_count += 1

	var total := 0.0
	for note_score in note_scores:
		total += note_score
	var average := total / note_scores.size() if not note_scores.is_empty() else 0.0

	return {
		"note_scores": note_scores,
		"note_judgements": note_judgements,
		"average": average,
		"hit_count": hit_count,
		"miss_count": note_scores.size() - hit_count,
		"note_count": note_scores.size(),
	}
