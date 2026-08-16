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
# WorldTimeStore.controller.advance(delta) 即可,不需要各自持有一份 WorldTime。快轉
# (toggle_fast_forward())是唯一的例外,靠這支 autoload 自己掛的 Timer 推進,不受
# 上述限制,也不受 is_playing 影響。
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

const FAST_FORWARD_INTERVAL := 0.1

var controller: WorldTimeController
var is_fast_forwarding: bool = false

var _fast_forward_timer: Timer


func _ready() -> void:
	controller = WorldTimeController.new()
	controller.register_day_event(func(): day_passed.emit())
	controller.register_month_event(func(): month_passed.emit())
	controller.register_year_event(func(): year_passed.emit())

	_fast_forward_timer = Timer.new()
	_fast_forward_timer.wait_time = FAST_FORWARD_INTERVAL
	_fast_forward_timer.one_shot = false
	_fast_forward_timer.timeout.connect(_on_fast_forward_tick)
	add_child(_fast_forward_timer)


func toggle_playing() -> void:
	controller.is_playing = not controller.is_playing


func get_display_string() -> String:
	return controller.world_time.get_display_string()


## HEADER 的超快速流逝時間按鈕(見 Scripts/UI/header_bar.gd)呼叫,切換後每
## FAST_FORWARD_INTERVAL 秒 +1 天,不受 is_playing 暫停狀態影響——快轉的意義就是
## 讓玩家在原地(例如停留在城堡)也能主動跳過時間,不需要先讓角色移動。
func toggle_fast_forward() -> void:
	is_fast_forwarding = not is_fast_forwarding
	if is_fast_forwarding:
		_fast_forward_timer.start()
	else:
		_fast_forward_timer.stop()


func _on_fast_forward_tick() -> void:
	controller.add_days(1)
