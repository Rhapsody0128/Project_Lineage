class_name WorldTime
extends RefCounted

## 大地圖的世界曆法時鐘,獨立於 MapSystem 運作——由 Scenes/Map/map.gd 在
## _process(delta) 主動呼叫 advance() 推進,自己不碰場景樹、不自己跑迴圈。
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


func _init(p_days_per_real_second: float = 1.0) -> void:
	days_per_real_second = p_days_per_real_second


func advance(delta: float) -> void:
	_day_accumulator += delta * days_per_real_second


func get_day_count() -> int:
	return int(floor(_day_accumulator))


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
