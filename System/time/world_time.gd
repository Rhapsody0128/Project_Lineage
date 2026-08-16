class_name WorldTime
extends RefCounted

## 世界曆法時鐘,純資料/算式,不碰場景樹、不自己跑迴圈——推進(advance()/add_days())
## 一律由 Scripts/Autoload/world_time_store.gd 呼叫(見 System/time/world_time_controller.gd),
## 不再由任一場景腳本(例如原本的 Scenes/Map/map.gd)持有/驅動。
##
## 簡化曆法:12 個月,每月固定 30 天,全年 360 天,不設閏年。
## 天文紀年(無「西元 0 年」問題):B.C.621 年 1 月 1 日 = 天文紀年 -620 年第 0 天,
## 天文紀年 <= 0 顯示為 B.C.(1 - 天文紀年),天文紀年 >= 1 顯示為 A.D.(天文紀年)。

const DAYS_PER_MONTH := 30
const MONTHS_PER_YEAR := 12
const DAYS_PER_YEAR := DAYS_PER_MONTH * MONTHS_PER_YEAR
const START_ASTRO_YEAR := -620

var days_per_real_second: float
var _day_accumulator: float = 0.0


func _init(p_days_per_real_second: float = 1.0, p_start_day_accumulator: float = 0.0) -> void:
	days_per_real_second = p_days_per_real_second
	_day_accumulator = p_start_day_accumulator


func advance(delta: float) -> void:
	_day_accumulator += delta * days_per_real_second


## 供快轉功能(HeaderBar 的超快速流逝時間按鈕)直接跳日用,不受 days_per_real_second
## 換算影響——按一次就是精確 +n 天,不會因為當下倍率設定而多走或少走。
func add_days(n: int) -> void:
	_day_accumulator += float(n)


func get_day_count() -> int:
	return int(floor(_day_accumulator))


## 存檔/還原用——目前世界時間鐘由 WorldTimeStore autoload 全程持有,不再需要
## 跨場景手動存讀,保留這個 getter 是給需要單獨顯示某個時間快照的呼叫端用。
func get_day_accumulator() -> float:
	return _day_accumulator


func get_astro_year() -> int:
	return START_ASTRO_YEAR + get_day_count() / DAYS_PER_YEAR


func get_month() -> int:
	var day_in_year := get_day_count() % DAYS_PER_YEAR
	return (day_in_year / DAYS_PER_MONTH) + 1


func get_day() -> int:
	var day_in_year := get_day_count() % DAYS_PER_YEAR
	return (day_in_year % DAYS_PER_MONTH) + 1


func get_display_string() -> String:
	var astro_year := get_astro_year()
	var era_str: String
	if astro_year <= 0:
		era_str = "B.C. %d" % (1 - astro_year)
	else:
		era_str = "A.D. %d" % astro_year
	return "%s 年 %d 月 %d 日" % [era_str, get_month(), get_day()]
