extends Node

# =========================================================
# 全域戰報存取點(autoload,見 project.godot)。屬於 Scenes 導覽/session 狀態
# (戰報列表 ↔ Battle 場景間的交接),不是戰鬥規則,所以放在 Scripts/ 而不是 System/——
# System/ 底下的類別全部是 RefCounted、不碰場景樹,這個檔案需要當 autoload(Node)。
# 存取方式先簡單用記憶體陣列裝著——戰報列表場景讀 reports 顯示清單,
# 播放戰報時把要播的那份存進 pending_report,再切去 Battle 場景,
# Battle 場景 _ready() 抓到 pending_report 就進入「播放模式」而不是
# 自己生一場新的隨機戰鬥。
#
# pending_self_party 是同一套交接模式,給 PartyEdit「以現在編成開始戰鬥」用:
# 把玩家編好的 Party 存進來,再切去 Battle 場景,Battle 場景 _ready() 抓到
# 就用這個小隊對上一個隨機敵方小隊,而不是雙方都隨機生。
#
# pending_enemy_party 是 AskBattle(見 Scenes/BattleUtil/ask_battle.gd)專用的加碼交接
# 欄位:敵方也是呼叫端指定的特定小隊(例如城門守衛),不是隨機生的——跟 pending_self_party
# 一起設定時,Battle 場景改用兩邊都指定的對戰,不會再幫敵方另外隨機生一支。
# =========================================================

var reports: Array[BattleReport] = []
var pending_report: BattleReport = null
## 跟 pending_report 同一套交接模式,給戰報列表「戰報」按鈕用:切去
## Scenes/BattleReportStats 顯示這場戰鬥的統計面板,不重播戰場畫面。
var pending_stats_report: BattleReport = null
## AskBattle 選「是，跳過」後彈出「是否觀看戰報？」問玩家,選「觀看戰報」才會用到:
## 存進要在 BattleReportStats 按「返回」時接續執行的動作(呼叫端原本該做的
## on_result callback 或切去 skip_return_scene_path,見 Scenes/BattleUtil/ask_battle.gd
## 的 _continue_after_battle())——不看報表的話這步直接跳過,不會設定這個欄位。
## battle_report_stats.gd 的 _on_back_pressed() 讀到有效 Callable 就改呼叫它取代預設的
## NavigationStore.go_back(),讀完立刻清空。
var pending_stats_continuation: Callable = Callable()
var pending_self_party: Party = null
var pending_enemy_party: Party = null
## 跟 pending_self_party 同一套交接模式:PartyEdit/main 場景切去 Battle 場景前設定,
## Battle 場景 _ready()/_new_simulation() 讀完就重設回預設值 AUTO,決定這場戰鬥是一次性
## 模擬完重播(AUTO),還是逐回合跑、回合間能手動施放奧義(REALTIME),見
## Scenes/Battle/battle.gd 的 _run_battle_realtime()。
var pending_battle_mode: GameEnums.BattleMode = GameEnums.BattleMode.AUTO

## AskBattle(選「否」進即時戰鬥)專用的加碼交接欄位:呼叫端想在戰鬥結束、玩家按下
## 「返回」時依勝負做點什麼(例如城門守衛戰鬥後依勝負秀不同台詞,見
## Scenes/MapLocation/map_location.gd 的 _on_guard_battle_result()),就把 Callable
## (簽章 func(result: GameEnums.BattleResultType))存進來;Battle 場景的
## _on_back_pressed() 讀到有效 Callable 就改呼叫它取代預設的 NavigationStore.go_back(),
## 讀完立刻清空,不會遺留到下一場沒有指定 callback 的一般戰鬥。
var pending_battle_result_callback: Callable = Callable()

func _ready() -> void:
	_seed_demo_reports()

## 開場先塞兩筆 DEMO 戰報,給戰報列表畫面一開始就有東西可看
func _seed_demo_reports() -> void:
	add_report(BattleController.generate_random_report(WorldTimeStore.get_display_string()))
	add_report(BattleController.generate_random_report(WorldTimeStore.get_display_string()))

func add_report(report: BattleReport) -> void:
	reports.append(report)

## 戰報列表「生成隨機戰報」DEMO 按鈕用:現跑一場隨機戰鬥、記錄成戰報並加入列表
func generate_demo_report() -> BattleReport:
	var report := BattleController.generate_random_report(WorldTimeStore.get_display_string())
	add_report(report)
	return report

## 指定要播放的戰報,呼叫端接著自行切換到 Battle 場景
func queue_playback(report: BattleReport) -> void:
	pending_report = report

## 指定要看統計的戰報,呼叫端接著自行切換到 BattleReportStats 場景
func queue_stats(report: BattleReport) -> void:
	pending_stats_report = report
