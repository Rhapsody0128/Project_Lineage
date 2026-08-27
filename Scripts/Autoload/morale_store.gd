extends Node

# =========================================================
# CHARACTER_ROSTER 整體的軍隊士氣(autoload,見 project.godot)。跟 NationFavorStore/
# BaseResourceStore 同一套慣例:這是 Scenes 層的 session 狀態,不是規則邏輯——士氣數值
# 換算成等級/效果的純規則在 System/morale/morale_rule.gd。只存「目前數值」跟少量供
# Header tooltip 顯示用的明細快取,連續 0~100 數值,不儲存「高/普通/低」這種等級字串,
# 等級一律用 MoraleRule 的門檻表現算現顯示。
#
# 士氣的漲跌來源集中在三個入口,呼叫端在對應時機呼叫這裡,不要繞過去直接改 value:
# - 經濟(每月結算糧食/薪水維持費,見 settle())——唯一會更新 _in_shortage 旗標的地方,
#   決定接下來戰績/事件造成的下跌能不能被「經濟健全時最低 40%」這條保護線擋住(見
#   CLAUDE.md「四、維持費不足」)。每月結算不是自己註冊 WorldTimeController,改由
#   MonthlySettlementStore 統一協調(見該檔案開頭註解)——糧食/薪水夠不夠看呼叫端傳入的
#   available 共用快照,不直接呼叫 BaseResourceStore.can_afford(),避免跟
#   BaseDispatchStore/BaseExchangeStore 同月搶同一份庫存時互相看到不該看到的即時異動。
# - 戰績:record_battle_result(),見 System/battle/battle_reward.gd 的 settle_morale()。
# - 重大事件/之後要加的小型隨機事件:record_event(),見角色結婚/死亡等呼叫點。
# =========================================================

signal changed

const START_VALUE := 60.0

## 每名角色每月維持費,見 CLAUDE.md「三、CHARACTER_ROSTER 維持費」。
const FOOD_PER_CHARACTER := 0.5
const WAGE_PER_CHARACTER := 0.2

## 經濟健全(糧食/薪水都付得出來)時,戰績/事件造成的下跌不會把士氣打穿這條保護線——
## 只有真的缺糧/欠薪的那個月才能突破它往下掉,見 _apply_delta()/settle()。
const MIN_MORALE_WHEN_SOLVENT := 40.0

## 單一項目(糧食或薪水)不足的當月額外扣減;兩項都不足時扣得更多,不是兩筆分開扣加總
## (加總會變成 -16,對兩頭都缺的隊伍懲罰太重,改用單一「更嚴重」的數值)。
const SHORTAGE_SINGLE_PENALTY := -6.0
const SHORTAGE_BOTH_PENALTY := -12.0

## 單場戰鬥對士氣的影響,不看敵方 RankType 強弱,固定幅度,見 CLAUDE.md「五、戰鬥對
## 士氣的影響」。故意不做連勝/連敗加成——每次都是固定小幅變動 + 0~100 封頂,自然避免
## 無限累積,不需要另外維護一個會一直漲的連勝計數器。
const BATTLE_WIN_DELTA := 3.0
const BATTLE_DRAW_DELTA := -1.0
const BATTLE_LOSE_DELTA := -3.0

const MARRIAGE_DELTA := 3.0
const DEATH_DELTA := -5.0

## 懷孕/新生兒也是值得慶祝的事,但份量不如結婚(整個家族的大事)——懷孕只是「即將有
## 好事發生」,酌量給一點;誕下孩子是真的多一位家族成員,給稍微多一點,見
## WorldTimeEventLibrary._roll_new_pregnancies()/_advance_pregnancies() 呼叫點。同一次
## 月結算若同時有好幾名角色懷孕/生產(角色數一多,機率湊在一起很常見),呼叫端不逐筆
## 各自計入、也不逐筆各占 tooltip 一行——加總成一筆,金額另外套下面兩個
## MAX_*_DELTA_PER_BATCH 封頂,避免後期角色一多,單一個月的家族喜事就輕鬆把士氣衝到頂。
const PREGNANCY_DELTA := 1.0
const CHILD_BORN_DELTA := 2.0
const MAX_PREGNANCY_DELTA_PER_BATCH := 3.0
const MAX_CHILD_BORN_DELTA_PER_BATCH := 4.0

## 新生兒命名畫面選擇「丟棄」(見 NewbornDiscardController.discard()):玩家主動放棄
## 剛出生的孩子,士氣下跌,幅度介於單場戰敗(BATTLE_LOSE_DELTA -3.0)跟角色死亡
## (DEATH_DELTA -5.0)之間——沒有死亡的震撼,但也不是無關痛癢的小事。
const DISCARD_CHILD_DELTA := -4.0

## Header tooltip「近期戰況」「其他事件」清單的「近期」定義:超過這麼多天的紀錄會過期
## 消失(見 _prune_expired()),不是按「這個月」整批清空——懷孕/新生兒等人生事件也是靠
## WorldTimeController.register_month_event() 觸發,若改成整批清空,一旦這裡的月結算
## (見 settle())排在同一次月份邊界的其他 month_event 之後執行,剛寫入的紀錄會在同一個
## tick 內被自己立刻清掉,tooltip 永遠看不到。60 天(2 個月,見 System/time/world_time.gd
## 的 DAYS_PER_MONTH)是兩份清單共用的同一套「近期」定義——事件比戰鬥稀少,不能各自訂一套
## 不同的過期規則,不然玩家會覺得「近期戰況」跟「其他事件」的「近期」代表不同意思。
const LOG_EXPIRY_DAYS := 60

## 上面的天數過期是主要機制,這裡只是防止極端情況(例如 DEMO 倍速下同一天內湧入大量
## 事件)讓清單無限長大的安全上限,不是「近期」的主要定義,平常不會被觸發到。
const LOG_HARD_CAP := 20

var value: float = START_VALUE

## 上個月結算時是否缺糧或欠薪,見 _apply_delta() 的保護線判斷。
var _in_shortage: bool = false

## 上次月結算的維持費/供應狀態快取,只給 Header tooltip 讀,不影響任何判定邏輯。
var last_food_cost: int = 0
var last_wage_cost: int = 0
var last_food_short: bool = false
var last_wage_short: bool = false

## 上次月結算因缺糧/欠薪實際扣掉的士氣(SHORTAGE_SINGLE_PENALTY/SHORTAGE_BOTH_PENALTY
## 其中一個,或兩者都不缺時是 0),只給 Header tooltip 顯示用——玩家要看得到「不足」
## 具體換算成多少士氣,不能只顯示「不足」兩個字卻不知道扣了多少。
var last_shortage_penalty: float = 0.0

## {"label": String, "delta": float, "day": int},見 LOG_EXPIRY_DAYS/_push_log()——不是
## 「這個月的」清單,不會在月結算時被清空,過期天數才是唯一的淘汰條件。呼叫端(Header
## tooltip)一律透過 get_recent_battle_log()/get_recent_event_log() 讀取,不要直接讀這兩個
## 欄位——過期清除只在寫入(_push_log())跟讀取(get_recent_*())兩個時機觸發,長時間沒有
## 新事件、也沒人打開過 tooltip 時,陣列裡可能暫時留著已過期的舊資料,要等下一次寫入或
## 讀取才會被清掉,不影響正確性(反正呈現前一定會先過一次 get_recent_*())。
var battle_log: Array[Dictionary] = []
var event_log: Array[Dictionary] = []


func get_roster_size() -> int:
	return CharacterRosterStore.all_characteres.size()


func get_recent_battle_log() -> Array[Dictionary]:
	_prune_expired(battle_log)
	return battle_log


func get_recent_event_log() -> Array[Dictionary]:
	_prune_expired(event_log)
	return event_log


func record_battle_result(result: int) -> void:
	match result:
		GameEnums.BattleResultType.SELF_WIN:
			_apply_delta(BATTLE_WIN_DELTA)
			_push_log(battle_log, "勝利", BATTLE_WIN_DELTA)
		GameEnums.BattleResultType.ENEMY_WIN:
			_apply_delta(BATTLE_LOSE_DELTA)
			_push_log(battle_log, "敗戰", BATTLE_LOSE_DELTA)
		GameEnums.BattleResultType.DRAW:
			_apply_delta(BATTLE_DRAW_DELTA)
			_push_log(battle_log, "平手", BATTLE_DRAW_DELTA)


## 重大人生事件(結婚/死亡)或之後要加的小型隨機事件共用的入口,label 直接是 tooltip
## 「其他事件」要顯示的中文說明。
func record_event(label: String, delta: float) -> void:
	_apply_delta(delta)
	_push_log(event_log, label, delta)


func _push_log(entries: Array[Dictionary], label: String, delta: float) -> void:
	entries.append({"label": label, "delta": delta, "day": _current_day()})
	_prune_expired(entries)
	if entries.size() > LOG_HARD_CAP:
		entries.pop_front()


func _current_day() -> int:
	return WorldTimeStore.controller.world_time.get_day_count()


## 依 LOG_EXPIRY_DAYS 淘汰過期紀錄——entries 一律按寫入順序排列(_push_log() 只會
## append),最舊的一定在最前面,從頭開始 pop 到剩下的都還沒過期就停,不用整個掃過一輪。
func _prune_expired(entries: Array[Dictionary]) -> void:
	var cutoff := _current_day() - LOG_EXPIRY_DAYS
	while not entries.is_empty() and entries[0].day < cutoff:
		entries.pop_front()


func _apply_delta(delta: float) -> void:
	value = clampf(value + delta, 0.0, 100.0)
	if not _in_shortage:
		value = maxf(value, MIN_MORALE_WHEN_SOLVENT)
	changed.emit()


## 共用結算迴圈:`apply == true` 時真的扣款/更新士氣(MonthlySettlementStore._run() 的
## _on_month_passed() 分支),否則只回傳淨變動量給 Scripts/UI/header_bar.gd 的「詳細」
## 面板顯示下月預估增減量,純預覽、不會真的執行。`available` 由呼叫端(MonthlySettlementStore
## ._run())在四支 store 的 settle() 都還沒呼叫之前一次補滿、貫穿整場月結算共用,糧食/薪水
## 夠不夠看這份快照而非即時庫存——原因見 base_dispatch_store.gd `_resolve_recipe()` 開頭
## 註解。下面兩個 `if not available.has(...)` 只是給「直接單獨呼叫這支 store 的 settle()」
## 時的防呆,正常路徑一律已經補好值。付不出來的項目直接不放進結果,付不出來那個月本來就
## 不會真的扣款,預覽不該顯示一個不會發生的扣款。
func settle(apply: bool, available: Dictionary) -> Dictionary:
	var roster_size := get_roster_size()
	var food_cost := roundi(roster_size * FOOD_PER_CHARACTER)
	var wage_cost := roundi(roster_size * WAGE_PER_CHARACTER)

	if not available.has(GameEnums.ResourceType.FOOD):
		available[GameEnums.ResourceType.FOOD] = BaseResourceStore.get_amount(GameEnums.ResourceType.FOOD)
	if not available.has(GameEnums.ResourceType.GOLD):
		available[GameEnums.ResourceType.GOLD] = BaseResourceStore.get_amount(GameEnums.ResourceType.GOLD)

	var food_short: bool = available[GameEnums.ResourceType.FOOD] < food_cost
	var wage_short: bool = available[GameEnums.ResourceType.GOLD] < wage_cost

	var delta: Dictionary = {}
	if food_cost > 0 and not food_short:
		available[GameEnums.ResourceType.FOOD] -= food_cost
		delta[GameEnums.ResourceType.FOOD] = -food_cost
	if wage_cost > 0 and not wage_short:
		available[GameEnums.ResourceType.GOLD] -= wage_cost
		delta[GameEnums.ResourceType.GOLD] = -wage_cost

	if not apply:
		return delta

	if food_cost > 0 and not food_short:
		BaseResourceStore.spend({GameEnums.ResourceType.FOOD: food_cost})
	if wage_cost > 0 and not wage_short:
		BaseResourceStore.spend({GameEnums.ResourceType.GOLD: wage_cost})

	last_food_cost = food_cost
	last_wage_cost = wage_cost
	last_food_short = food_short
	last_wage_short = wage_short
	_in_shortage = food_short or wage_short

	var economic_delta := 0.0
	if food_short and wage_short:
		economic_delta = SHORTAGE_BOTH_PENALTY
	elif food_short or wage_short:
		economic_delta = SHORTAGE_SINGLE_PENALTY
	last_shortage_penalty = economic_delta

	## 不能沿用 _apply_delta()——_in_shortage 這時已經更新成這個月的最新狀態,經濟健全
	## (economic_delta 為 0)的話會順勢把士氣拉回保護線之上,不需要另外處理「缺糧解除後
	## 士氣要不要回彈」。
	value = clampf(value + economic_delta, 0.0, 100.0)
	if not _in_shortage:
		value = maxf(value, MIN_MORALE_WHEN_SOLVENT)

	changed.emit()
	return delta


func to_save_data() -> Dictionary:
	return {"value": value, "in_shortage": _in_shortage}


func load_save_data(data: Dictionary) -> void:
	value = float(data.get("value", START_VALUE))
	_in_shortage = bool(data.get("in_shortage", false))
	battle_log.clear()
	event_log.clear()
	changed.emit()
