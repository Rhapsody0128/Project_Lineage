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
# pending_enemy_party 是加碼交接欄位:敵方也是呼叫端指定的特定小隊,不是隨機生
# 的——跟 pending_self_party 一起設定時,Battle 場景改用兩邊都指定的對戰,不會再幫
# 敵方另外隨機生一支。兩個呼叫端會用到:AskBattle(見 Scenes/BattleUtil/ask_battle.gd,
# 例如城門守衛戰鬥)、PartyEdit「加強DEMO戰鬥角色」開關按下時(敵方換成呼叫端自己先
# 用較高 RankType 生好的小隊,見 Scenes/PartyEdit/party_edit.gd)。
# =========================================================

var reports: Array[BattleReport] = []
var pending_report: BattleReport = null
## 戰爭戰報(WarCampaignController 連續作戰打完的結果集合)——跟 reports 分開存放,戰報
## 列表的「戰爭戰報」分類讀這裡,展開手風琴直接內嵌顯示 fight_reports,見
## Scenes/BattleReportList/battle_report_list.gd。比照 reports 不存檔。
var war_campaign_reports: Array[WarCampaignReport] = []
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

## AskBattle 的加碼交接欄位(選「否」進即時戰鬥時用):跟 pending_battle_result_callback
## 同一套模式,但傳的是完整 BattleReport(簽章 func(report: BattleReport))而不是只有
## 勝負結果——給需要保留這場戰鬥完整戰報的呼叫端用(例如 WarBattleEvent 連續作戰要把每
## 一場的 BattleReport 收進 WarCampaignReport.fight_reports)。battle.gd 的
## _record_battle_report() 讀到有效 Callable 就順便呼叫一次,讀完立刻清空,不會遺留到
## 下一場沒有指定 callback 的一般戰鬥。
var pending_battle_report_callback: Callable = Callable()

## 跟 pending_battle_report_callback 同一套交接模式(AskBattle 選「否」進即時戰鬥時用):
## 這場戰鬥打完要不要寫進 reports(「一般戰鬥」清單)、BattleReport.description 要用什麼
## 文字——分別對應 AskBattle.ask() 的 record_in_report_list/report_description 參數,見
## 該處欄位註解。battle.gd 的 _record_battle_report() 讀完立刻重設回預設值(true/""),
## 不會遺留到下一場沒有指定的一般戰鬥。
var pending_battle_record_in_report_list: bool = true
var pending_battle_report_description: String = ""

## 同一套交接模式,對應 AskBattle.ask() 的 grant_nation_favor 參數:這場戰鬥打贏
## 要不要順帶呼叫 BattleReward.grant_victory_favor()。預設 true(維持原本行為);
## WarBattleEvent 連續作戰傳 false,見該參數欄位註解。battle.gd 的 _record_battle_report()
## 讀完立刻重設回預設值 true。
var pending_battle_grant_nation_favor: bool = true

## 戰報列表畫面自己的 UI 狀態(目前分頁/展開中的戰爭戰報),不是戰報資料本身——切去
## 觀戰/戰報統計場景再按返回時,battle_report_list.gd 的節點早就被銷毀重建過,靠這裡的
## session 記憶還原成離開當下的樣子(見該檔案 CATEGORY_NORMAL/CATEGORY_WAR),不寫存檔、
## 不跨遊戲啟動保留。
## 數值對應 battle_report_list.gd 的 CATEGORY_NORMAL(0)/CATEGORY_WAR(1),這裡故意不
## 直接引用那兩個常數(Scripts/Autoload 不依賴 Scenes 底下的場景腳本),呼叫端自己對照。
var list_last_category: int = 0
var list_expanded_war_report_ids: Dictionary = {}

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

func add_war_campaign_report(report: WarCampaignReport) -> void:
	war_campaign_reports.append(report)
