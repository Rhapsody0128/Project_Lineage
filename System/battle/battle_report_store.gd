extends Node

# =========================================================
# 全域戰報存取點(autoload,見 project.godot)。
# 存取方式先簡單用記憶體陣列裝著——戰報列表場景讀 reports 顯示清單,
# 播放戰報時把要播的那份存進 pending_report,再切去 Battle 場景,
# Battle 場景 _ready() 抓到 pending_report 就進入「播放模式」而不是
# 自己生一場新的隨機戰鬥。
# =========================================================

var reports: Array[BattleReport] = []
var pending_report: BattleReport = null

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
