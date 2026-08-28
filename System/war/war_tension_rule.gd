class_name WarTensionRule
extends RefCounted

## WarTension(0-100)相關的純數值規則,實際儲存在 NationRelationStore。

## 和平期間(雙方都沒有進行中的戰爭)每年自然衰減量,見 war_world_time_events.gd
## yearly_tick() 的 _decay_peacetime_tension()。
const PEACETIME_YEARLY_DECAY := 3.0

## Phase 2(WarDiplomacyAi._pick_target())候選門檻:低於這個值的國家不會被列入宣戰
## 候選名單。
const DECLARE_CANDIDATE_TENSION_THRESHOLD := 70.0

## 開場時每組國家對的起始 WarTension 上限,見 NationRelationStore._seed_random_tensions()。
## 原本預設一律是 0(穩定和平),要爬到 DECLARE_CANDIDATE_TENSION_THRESHOLD 得靠很多年月的
## 隨機波動慢慢累積,戰爭幾乎不會發生——改成開局就給每組國家對一個 0~此值的隨機起始值,
## 讓一開始就有機會出現幾組已經偏緊張的國家對。
const INITIAL_TENSION_MAX := 50.0

## 每個月對每一組沒有進行中戰爭的國家對套用的隨機波動上限(邊境衝突/資源爭奪等瑣碎
## 摩擦的簡化版,見 spec「和平期間 WarTension」),見 war_world_time_events.gd
## monthly_tick() 的 _apply_random_tension_drift()。跟 PEACETIME_YEARLY_DECAY 同時
## 存在:decay 是長期把關係拉回和平的系統性力道,這裡是疊加在上面、有正有負的短期
## 隨機事件雜訊,兩者一起才會讓 WarTension 自然爬升到宣戰候選門檻,而不是只會單調下降。
## 原本 10.0 太保守,張力幾乎爬不到 DECLARE_CANDIDATE_TENSION_THRESHOLD,戰爭觸發機率
## 太低,調大到 20.0 讓波動更明顯。
const MONTHLY_RANDOM_DRIFT_RANGE := 20.0


## 七個 WarTension 區間標籤,供 debug/未來 UI 使用。
static func band_for(tension: float) -> String:
	if tension < 20.0:
		return "穩定和平"
	elif tension < 40.0:
		return "穩定"
	elif tension < 60.0:
		return "緊張"
	elif tension < 70.0:
		return "敵對"
	elif tension < 80.0:
		return "高風險"
	elif tension < 90.0:
		return "極端"
	return "危急"
