class_name WorldTime
extends RefCounted

## 世界曆法時鐘,純資料/算式,不碰場景樹、不自己跑迴圈——推進(advance())一律由
## Scripts/Autoload/world_time_store.gd 呼叫(見 System/time/world_time_controller.gd),
## 不再由任一場景腳本(例如原本的 Scenes/Map/map.gd)持有/驅動。
##
## 簡化曆法:12 個月,每月固定 30 天,全年 360 天,不設閏年。架空紀年,不對應真實
## 西元/BC 換算——遊戲開始(day_count 0)固定是 START_YEAR 年 1 月 1 日,年份只會隨
## day_count 增加往上加,不需要、也不支援往回推算成負數年份。

const DAYS_PER_MONTH := 30
const MONTHS_PER_YEAR := 12
const DAYS_PER_YEAR := DAYS_PER_MONTH * MONTHS_PER_YEAR
const START_YEAR := 116

var days_per_real_second: float
var _day_accumulator: float = 0.0


func _init(p_days_per_real_second: float = 1.0, p_start_day_accumulator: float = 0.0) -> void:
	days_per_real_second = p_days_per_real_second
	_day_accumulator = p_start_day_accumulator


func advance(delta: float) -> void:
	_day_accumulator += delta * days_per_real_second


func get_day_count() -> int:
	return int(floor(_day_accumulator))


## 存檔/還原用——目前世界時間鐘由 WorldTimeStore autoload 全程持有,不再需要
## 跨場景手動存讀,保留這個 getter 是給需要單獨顯示某個時間快照的呼叫端用。
func get_day_accumulator() -> float:
	return _day_accumulator


func get_year() -> int:
	return START_YEAR + get_day_count() / DAYS_PER_YEAR


func get_month() -> int:
	var day_in_year := get_day_count() % DAYS_PER_YEAR
	return (day_in_year / DAYS_PER_MONTH) + 1


func get_day() -> int:
	var day_in_year := get_day_count() % DAYS_PER_YEAR
	return (day_in_year % DAYS_PER_MONTH) + 1


func get_display_string() -> String:
	return "%d年%d月%d日" % [get_year(), get_month(), get_day()]
