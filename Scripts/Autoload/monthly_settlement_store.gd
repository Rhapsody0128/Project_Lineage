extends Node

# =========================================================
# 每月結算的唯一協調者(autoload,見 project.godot)。BaseDispatchStore(建築派遣生產/
# 配方消耗)、BaseExchangeStore(商隊站/黑市自動兌換)、MoraleStore(CHARACTER_ROSTER
# 糧食/薪水維持費)、CastleStore(城堡佔領收入)四者都會在同一個月份邊界動用同一份
# BaseResourceStore 庫存。若各自獨立呼叫 WorldTimeController.register_month_event()、
# 各自即時讀寫 BaseResourceStore,會出現「先執行的那個把資源用掉/生出來,後執行的用到
# 不該看到的當月庫存變動」的競態——例如月初毛皮不夠抄書院消耗、原本整個月不該生產書本,
# 但商隊站賣毛皮的自動兌換訂單卻因為排在狩獵場後面執行,用到狩獵場當月剛產出的毛皮成交;
# 反過來,月結算「詳細」預覽只各自獨立試算,沒把其他三者當月的消耗/產出算進去,也會跟
# 實際執行結果兜不起來。
#
# 這裡是唯一向 WorldTimeController 註冊月結算的地方,四支 store 原本各自的
# register_month_event() 已移除、_on_month_passed()/get_projected_monthly_delta() 也
# 收斂成同一個介面 settle(apply, available, ...)(CastleStore 純產出不吃 available/
# remaining_capacity,見 System/base 對應檔案開頭註解;MoraleStore 只吃 available,糧食/
# 薪水不是「產物」,不需要判斷倉庫還放不放得下)。結算時維護一份 `available`(本月結算
# 尚未動用的庫存快照,之後只會被消耗方扣減,不會被本月任何一方的產出灌回去——產出一律
# 只進 delta/BaseResourceStore,下個月才算「庫存」),依固定優先序依序傳給四者的
# settle():
#
# `available`/`remaining_capacity` 兩份快照一律在下面 `_run()` 開頭、四者的 settle() 都
# 還沒呼叫之前,對全部 GameEnums.ResourceType 一次補滿,不能像過去那樣交給各 store 的
# settle() 自己「第一次用到某資源時才從 BaseResourceStore 補值」——apply == true 時
# BaseDispatchStore.settle() 的迴圈跑到一半就會直接呼叫 BaseResourceStore.add()/
# spend() 寫回真正庫存(見該檔案 settle()),如果某資源要等到迴圈跑到後段的建築(例如
# 抄書院消耗毛皮)才第一次讀 available,讀到的 BaseResourceStore.get_amount() 就已經是
# 前面建築(例如狩獵場產毛皮)這個月剛寫回的新值,等於讓後面的消耗方看到本月才剛產出的
# 資源、跟預覽(apply == false,BaseResourceStore 全程沒被動過)算出的結果兜不起來——
# 前面建築在迴圈裡的順序純粹是 BuildingLibrary.get_all() 的排列,不該影響哪個消耗方能不
# 能用到本月產出。`remaining_capacity` 是同一份精神的另一半:各資源倉庫「還放得下多少」
# 的快照,BaseDispatchStore 生產、BaseExchangeStore 兌換買入都會邊執行邊扣減同一份字典
# (比照 available 被消耗方扣減),讓排在後面的一方看到的是「前面已經用掉多少倉庫空間」,
# 不會兩邊都以為倉庫是空的而各自超買——BaseExchangeStore 買入/賣出快頂到倉庫上限時不是
# 整筆整月不換,而是砍到剛好塞滿、來源花費跟著等比例減少(見該檔案開頭註解),不像
# BaseDispatchStore 的生產維持「整棟跳過、不生產」的簡化(沒有直接金錢成本,見該檔案)。
# 四支 store 各自 settle() 裡仍保留的 `if not available.has(...)`/
# `if not remaining_capacity.has(...)` 只是給「直接單獨呼叫這支 store 的 settle()」這種
# 情境的防呆,正常路徑(經由這裡的 `_run()`)一律命中已經補好的值,不會再落到那個分支。
#
#   1. BaseDispatchStore — 根據地派駐生產,玩法核心,配方消耗優先吃到期初庫存/優先佔用
#                          倉庫空間。
#   2. MoraleStore       — CHARACTER_ROSTER 糧食/薪水維持費,視為必要開銷。
#   3. BaseExchangeStore — 商隊站/黑市自動兌換,玩家自行設定的量,優先序最低,不會為了
#                          兌換排擠掉生產/維持費。
#   4. CastleStore       — 純產出、不消耗,不受這個競態影響,順序放最後即可。
#
# get_projected_monthly_delta() 給 Scripts/UI/header_bar.gd 的「詳細」面板用,跟
# _on_month_passed() 共用同一個 _run(apply),保證預覽跟實際結算永遠一致。
# =========================================================


func _ready() -> void:
	WorldTimeStore.controller.register_month_event(_on_month_passed)


func get_projected_monthly_delta() -> Dictionary:
	return _run(false)


func _on_month_passed() -> void:
	_run(true)


func _run(apply: bool) -> Dictionary:
	var available: Dictionary = {}
	var remaining_capacity: Dictionary = {}
	for resource_type in GameEnums.ResourceType.values():
		available[resource_type] = BaseResourceStore.get_amount(resource_type)
		remaining_capacity[resource_type] = BaseResourceStore.remaining_capacity(resource_type)
	var delta := BaseDispatchStore.settle(apply, available, remaining_capacity)
	_merge_into(delta, MoraleStore.settle(apply, available))
	_merge_into(delta, BaseExchangeStore.settle(apply, available, remaining_capacity))
	_merge_into(delta, CastleStore.settle(apply))
	return delta


func _merge_into(delta: Dictionary, extra: Dictionary) -> void:
	for resource_type in extra:
		delta[resource_type] = delta.get(resource_type, 0) + extra[resource_type]
