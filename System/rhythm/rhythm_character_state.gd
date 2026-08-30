class_name RhythmCharacterState
extends RefCounted

## 測試畫面(RhythmPlayView)下方角色動作圖輪播的狀態機:純函式,只吃「目前經過秒數」+
## 一組時間戳 + 這個建築實際擁有哪些狀態圖(available,直接傳 _character_textures 這個
## Dictionary 即可)算出該顯示哪張圖,不碰任何 Node/Texture——實際換圖由 Scenes 層做。
## 呼叫端(RhythmPlayView)目前是拿「玩家正確譜」(correct_beats)驅動,不是提示譜——動作圖
## 要對齊的是「正確答案該打下去的那一下」,不是提示音本身的時間點。
##
## 各建築素材不保證完全一致(見 RhythmChartStore 素材資料夾註解),available 決定要走
## 哪個變體:
## - HOLD2 缺席就不做待機互換,固定顯示 HOLD。
## - 同時有 HINT1/HINT2 才走「分兩段」變體(提示窗從單段的 ACTION_INTERVAL 加倍成
##   2 * ACTION_INTERVAL=1 秒,前半段 HINT1、後半段 HINT2);否則走單一 HINT、窗長維持
##   原本的 ACTION_INTERVAL。
## - FAIL 是玩家「敲 MISS」當下的反應圖,不是由時間戳算出來的(跟 HOLD/HINT/HIT/FIN 這條
##   純時間軸邏輯是分開的兩件事,這裡只定義共用的 HIT_HOLD_DURATION),呼叫端要自己在
##   判定出 MISS 的當下另外覆蓋顯示,見 RhythmPlayView._judge_tap()。
##
## 規則(依需求原文):
## - 平常(不靠近任何節點)HOLD/HOLD2 每隔一個 ACTION_INTERVAL(0.5 秒)互相切換(待機動畫)。
##   缺 HOLD2 的建築固定顯示 HOLD,不切換。
## - 每個節點時間戳往前推一個提示窗起換成提示圖(單段 HINT 是 ACTION_INTERVAL;
##   HINT1+HINT2 兩段合計 1 秒,前半段 HINT1、後半段 HINT2)。
## - 時間戳當下精準切換成 HIT,只顯示 HIT_HOLD_DURATION(0.1 秒)就切回待機(HOLD),不是
##   跟 HINT 對稱的 0.5 秒。
## - 最後一個節點的 HIT 顯示區間(HIT_HOLD_DURATION)結束後,不是切回 HOLD,而是換成 FIN,
##   維持到整段小遊戲(CHART_DURATION_SEC)結束為止。

const HOLD := "HOLD"
const HOLD2 := "HOLD2"
const HINT := "HINT"
const HINT1 := "HINT1"
const HINT2 := "HINT2"
const HIT := "HIT"
const FIN := "FIN"
const FAIL := "FAIL"

const ACTION_INTERVAL := 0.5
const HIT_HOLD_DURATION := 0.1


## beats 不要求呼叫端先排序,這裡自己排——時間戳照理是遞增的,但防呆一下不吃虧。
static func state_for(t: float, beats: Array[float], available: Dictionary) -> String:
	if beats.is_empty():
		return _idle_state(t, available)

	var sorted_beats := beats.duplicate()
	sorted_beats.sort()

	var split_hint: bool = available.has(HINT1) and available.has(HINT2)
	var hint_window: float = ACTION_INTERVAL * 2.0 if split_hint else ACTION_INTERVAL

	var last_beat: float = sorted_beats[sorted_beats.size() - 1]
	if t >= last_beat + HIT_HOLD_DURATION:
		return FIN

	for beat in sorted_beats:
		if t >= beat - hint_window and t < beat:
			if split_hint:
				return HINT1 if t < beat - ACTION_INTERVAL else HINT2
			return HINT
		if t >= beat and t < beat + HIT_HOLD_DURATION:
			return HIT

	return _idle_state(t, available)


static func _idle_state(t: float, available: Dictionary) -> String:
	if not available.has(HOLD2):
		return HOLD
	var cycle := int(t / ACTION_INTERVAL)
	return HOLD if cycle % 2 == 0 else HOLD2
