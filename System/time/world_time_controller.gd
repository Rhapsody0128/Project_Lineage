class_name WorldTimeController
extends RefCounted

## 世界時間的推進 + 固定事件派發規則(見 CLAUDE.md「System 管邏輯」)。持有一份
## WorldTime 時鐘,包一層「今天/這個月/這一年有沒有跨過去」的偵測,推進後跨過的每一天
## 依序觸發 day/month/year 註冊事件——不是「每 frame 觸發」,是「每跨過一天邊界觸發一次」,
## 快轉(add_days 一次跳好幾天)一樣會逐天觸發,不會漏掉中間跨越的月/年事件。
##
## 誰來推進(advance()/add_days())見 Scripts/Autoload/world_time_store.gd,這裡只管
## 「推進後該通知誰」,不自己跑迴圈、不碰場景樹。
##
## 注意 RefCounted 生命週期陷阱(見 CLAUDE.md):這個 controller 是應用程式全程存活的
## 全域物件(掛在 WorldTimeStore autoload 下面),register_xxx_event() 存進來的 Callable
## 若是直接傳裸方法參照(例如 `some_node.some_method`)而呼叫端本身是 RefCounted,
## 只會存 ObjectID、不會撐住引用計數,呼叫端物件一旦被釋放,這裡的 Callable 會悄悄失效
## (`is_valid()` 回傳 false,不會報錯)。真的需要用 RefCounted 物件的方法當事件時,
## 呼叫端要自己確保有其他地方強參照住自己,或改包一層閉包捕捉 self。

var world_time: WorldTime
var is_playing: bool = false

var _day_events: Array[Callable] = []
var _month_events: Array[Callable] = []
var _year_events: Array[Callable] = []


func _init(p_world_time: WorldTime = null) -> void:
	world_time = p_world_time if p_world_time != null else WorldTime.new()


func register_day_event(callback: Callable) -> void:
	_day_events.append(callback)


func register_month_event(callback: Callable) -> void:
	_month_events.append(callback)


func register_year_event(callback: Callable) -> void:
	_year_events.append(callback)


## 依真實時間流逝推進——is_playing 為 false(暫停中)時整段不動作,時間跟固定事件
## 都一起凍結。
func advance(delta: float) -> void:
	if not is_playing:
		return
	_advance_and_dispatch(world_time.advance.bind(delta))


## 快轉專用:精確跳過 n 天(不受 is_playing/days_per_real_second 影響),見
## Scripts/UI/header_bar.gd 的超快速流逝時間按鈕。
func add_days(n: int) -> void:
	_advance_and_dispatch(world_time.add_days.bind(n))


func _advance_and_dispatch(advance_call: Callable) -> void:
	var before_days := world_time.get_day_count()
	advance_call.call()
	var after_days := world_time.get_day_count()
	for day_count in range(before_days + 1, after_days + 1):
		_dispatch(_day_events)
		if day_count % WorldTime.DAYS_PER_MONTH == 0:
			_dispatch(_month_events)
		if day_count % WorldTime.DAYS_PER_YEAR == 0:
			_dispatch(_year_events)


func _dispatch(callbacks: Array[Callable]) -> void:
	for callback in callbacks:
		if callback.is_valid():
			callback.call()
