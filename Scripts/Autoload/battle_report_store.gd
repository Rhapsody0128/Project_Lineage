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
# =========================================================

var reports: Array[BattleReport] = []
var pending_report: BattleReport = null
var pending_self_party: Party = null

func _ready() -> void:
	_seed_demo_reports()

## 開場先塞兩筆 DEMO 戰報,給戰報列表畫面一開始就有東西可看
func _seed_demo_reports() -> void:
	add_report(BattleController.generate_random_report("示範戰報一"))
	add_report(BattleController.generate_random_report("示範戰報二"))

func add_report(report: BattleReport) -> void:
	reports.append(report)

## 戰報列表「生成隨機戰報」DEMO 按鈕用:現跑一場隨機戰鬥、記錄成戰報並加入列表
func generate_demo_report() -> BattleReport:
	var report := BattleController.generate_random_report("隨機戰報 %d" % (reports.size() + 1))
	add_report(report)
	return report

## 指定要播放的戰報,呼叫端接著自行切換到 Battle 場景
func queue_playback(report: BattleReport) -> void:
	pending_report = report
