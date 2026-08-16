extends Node

# =========================================================
# 全域世界時間時鐘(autoload,見 project.godot)。WorldTime/WorldTimeController 是
# System 層的純邏輯(System/time/),這支 autoload 是它們唯一的持有者、應用程式全程
# 存活——不再像過去那樣讓 Scenes/Map/map.gd 自己 new 一份 WorldTime、進出地圖時
# 手動把 day_accumulator/is_playing 存進 MapSessionStore 再讀出來還原。
#
# 這裡只是「時鐘 + 派發規則」的存放處,不會自己每 frame 推進(RefCounted 不能自己
# 掛 _process(),而且不是每個場景都需要世界時間在跑)——真正呼叫 advance() 的地方是
# Scenes/Map/map.gd 的 _process()(遊戲裡目前只有大地圖移動時世界時間才會走,離開
# 大地圖跟過去一樣暫停),之後若有第二個場景也想推進時間,一樣呼叫
# WorldTimeStore.controller.advance(delta) 即可,不需要各自持有一份 WorldTime。DEMO 快轉
# (set_speed_level(4),is_fast_forwarding 為真)是唯一的例外,靠這支 autoload 自己掛的
# Timer 推進,不受上述限制,也不受 is_playing 影響。
#
# project.godot 的 [autoload] 區塊裡這支必須排在最前面:controller 是在 _ready()
# 才 new 出來,其他 autoload 若在自己的 _ready() 就呼叫 WorldTimeStore.get_display_string()
# 之類的方法(例如 BattleReportStore._seed_demo_reports()),排在 WorldTimeStore 前面的
# 話會讀到還沒初始化的 controller(Nil),直接噴「Invalid access ... on a base object of
# type 'Nil'」。
#
# 其他系統要在「跨過一天/月/年邊界」時收到通知,有兩種管道:
# - System 層(RefCounted 規則邏輯):直接呼叫 WorldTimeStore.controller.register_day_event()/
#   register_month_event()/register_year_event(),見 System/time/world_time_controller.gd
#   開頭的 RefCounted 生命週期陷阱警告。
# - Scenes 層(場景腳本):接這支 autoload 的 day_passed/month_passed/year_passed 訊號,
#   Node 的訊號連線會在場景節點釋放時自動斷開,不會有殘留(見 Scenes/Map/map.gd 用
#   day_passed 驅動小隊 HP 自然回復)。
# =========================================================

signal day_passed
signal month_passed
signal year_passed

const FAST_FORWARD_INTERVAL := 0.01
## 快轉時角色移動速度的加速倍率:跟「快轉讓時間跳多快」用同一把尺——正常播放時
## 1 真實秒 = 1 遊戲天(WorldTime.days_per_real_second 預設 1.0),快轉是 0.01 秒
## 跳 1 天,換算下來等於 100 倍。Scenes/Map/map.gd 移動時額外拿這個倍率乘 delta,
## 讓走路速度跟時間流逝速度維持同一套加速比例,不會發生「時間用力跳、角色卻慢慢走」
## 的違和感。
const FAST_FORWARD_MOVE_MULTIPLIER := 1.0 / FAST_FORWARD_INTERVAL

var controller: WorldTimeController
## 一般倍速(1x/2x/3x),跟 is_fast_forwarding 互斥——切到快轉時這個值固定回 1.0,
## 見 set_speed_level()。Scenes/Map/map.gd 的 _process() 拿這個值乘 delta,同時套用在
## 世界時間推進與地圖移動上,讓「幾倍速」的感覺是整體一起變快,不是只有時間跳、
## 角色還是慢慢走。
var play_speed_multiplier: float = 1.0
var is_fast_forwarding: bool = false

var _fast_forward_timer: Timer


func _ready() -> void:
	controller = WorldTimeController.new()
	controller.register_day_event(func(): day_passed.emit())
	controller.register_month_event(func(): month_passed.emit())
	controller.register_year_event(func(): year_passed.emit())
	WorldTimeEventLibrary.register_all(controller)

	_fast_forward_timer = Timer.new()
	_fast_forward_timer.wait_time = FAST_FORWARD_INTERVAL
	_fast_forward_timer.one_shot = false
	_fast_forward_timer.timeout.connect(_on_fast_forward_tick)
	add_child(_fast_forward_timer)


func toggle_playing() -> void:
	controller.is_playing = not controller.is_playing


func get_display_string() -> String:
	return controller.world_time.get_display_string()


## HEADER 的倍速按鈕/鍵盤 1~4(見 Scripts/UI/header_bar.gd 與 Scenes/Map/map.gd)統一
## 呼叫的入口。1~3 對應一般倍速(play_speed_multiplier = 1.0/2.0/3.0);4 對應原本的
## DEMO 100 倍速快轉(沿用 is_fast_forwarding 的 Timer 機制——不受 is_playing 暫停狀態
## 影響,讓玩家在原地也能主動跳過時間,不需要先讓角色移動)。四個等級互斥,切到任一個
## 都會關掉另一種模式。
func set_speed_level(level: int) -> void:
	if level >= 4:
		play_speed_multiplier = 1.0
		if not is_fast_forwarding:
			is_fast_forwarding = true
			_fast_forward_timer.start()
		return
	if is_fast_forwarding:
		is_fast_forwarding = false
		_fast_forward_timer.stop()
	play_speed_multiplier = float(clampi(level, 1, 3))


func _on_fast_forward_tick() -> void:
	controller.add_days(1)
