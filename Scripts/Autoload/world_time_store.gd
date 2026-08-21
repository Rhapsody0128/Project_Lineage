extends Node

# =========================================================
# 全域世界時間時鐘(autoload,見 project.godot)。WorldTime/WorldTimeController 是
# System 層的純邏輯(System/time/),這支 autoload 是它們唯一的持有者、應用程式全程
# 存活——不再像過去那樣讓 Scenes/Map/map.gd 自己 new 一份 WorldTime、進出地圖時
# 手動把 day_accumulator/is_playing 存進 MapSessionStore 再讀出來還原。
#
# 這裡只是「時鐘 + 派發規則」的存放處,不會自己每 frame 推進(RefCounted 不能自己
# 掛 _process(),而且不是每個場景都需要世界時間在跑)——真正呼叫 advance() 的地方是
# Scripts/UI/header_bar.gd 的 _process()(HeaderBar 是全域唯一的倍速/暫停控制入口,
# 只要場景掛了 HeaderBar,is_playing 為真時世界時間就會走;沒掛 HeaderBar 的場景——例如
# MapLocation 的地點選單——本來就把 is_playing 停在 false,不需要推進)。DEMO 快轉
# (set_speed_level(4))跟 1x/2x/3x 走同一條路——單純是 play_speed_multiplier 換成更大的
# 倍率,一樣受 is_playing 控管,沒有另開 Timer/繞過暫停的特殊通道。
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

## 倍速等級(1/2/3/4)→ play_speed_multiplier,4 是 HeaderBar 上 DEMO 按鈕用的 100 倍速
## (見 Scripts/UI/header_bar.gd)。四個等級走同一套 set_speed_level() 入口、同一份
## play_speed_multiplier,DEMO 沒有另外的 Timer 或繞過 is_playing 的特殊通道——純粹是
## 數字比較大而已。
const SPEED_MULTIPLIERS := {1: 1.0, 2: 2.0, 3: 3.0, 4: 100.0}

var controller: WorldTimeController
## 目前的倍速等級(1~4),HeaderBar 重新建立節點時用這個同步按鈕外觀(見
## Scripts/UI/header_bar.gd 的 _ready())。
var speed_level: int = 1
## 目前的倍速倍率,HeaderBar._process() 拿這個值乘 delta 推進世界時間(見上方說明),
## Scenes/Map/map.gd._process() 移動地圖角色時也拿同一份值乘 delta,讓「幾倍速」的感覺
## 是整體一起變快,不是只有時間跳、角色還是慢慢走。
var play_speed_multiplier: float = 1.0


func _ready() -> void:
	controller = WorldTimeController.new()
	controller.register_day_event(func(): day_passed.emit())
	controller.register_month_event(func(): month_passed.emit())
	controller.register_year_event(func(): year_passed.emit())
	WorldTimeEventLibrary.register_all(controller)


func toggle_playing() -> void:
	set_playing(not controller.is_playing)


## HeaderBar 的時間播放列(Scripts/UI/header_bar.gd 的 TIMEPLAYER 圖組)點「暫停」/
## 「▶1x」/「2x」/「3x」四顆各自要明確設成暫停或播放中,不是切換,所以獨立出這支給
## toggle_playing() 跟按鈕共用,不用各自重複寫 controller.is_playing = ...。
func set_playing(value: bool) -> void:
	controller.is_playing = value


func get_display_string() -> String:
	return controller.world_time.get_display_string()


## HeaderBar 的倍速按鈕/鍵盤 1~4(見 Scripts/UI/header_bar.gd)統一呼叫的入口,四個
## 等級都走同一段邏輯,只是 play_speed_multiplier 的數字不同,沒有特殊通道。
func set_speed_level(level: int) -> void:
	speed_level = clampi(level, 1, 4)
	play_speed_multiplier = SPEED_MULTIPLIERS[speed_level]


## 存檔/讀檔用:只換掉 controller.world_time(時鐘本身)跟 is_playing/speed_level,
## 不能整個重 new 一顆 WorldTimeController——那樣會連帶弄丟 _ready() 時各 store 已經
## 註冊好的 day/month/year 事件(見 CLAUDE.md「世界時間」的 RefCounted 生命週期陷阱)。
func to_save_data() -> Dictionary:
	return {
		"day_accumulator": controller.world_time.get_day_accumulator(),
		"is_playing": controller.is_playing,
		"speed_level": speed_level,
	}


func load_save_data(data: Dictionary) -> void:
	controller.world_time = WorldTime.new(1.0, float(data.get("day_accumulator", 0.0)))
	controller.is_playing = data.get("is_playing", false)
	set_speed_level(int(data.get("speed_level", 1)))
