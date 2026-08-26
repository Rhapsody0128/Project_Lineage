extends Node

# =========================================================
# 玩家目前持有的任務清單(autoload,見 project.godot)。跟 NationFavorStore 同一套慣例:
# 這是 Scenes 層的 session 狀態,任務怎麼生成/文案/期限天數等靜態規則在
# System/quest/quest_library.gd。
#
# 三種委託任務(討伐/交貨/送信)都是玩家在 TownTavernEvent 酒館老闆「詢問委託」面板
# 按下「接受」時,拿 QuestLibrary.create_offer() 現場生成的一次性報價塞進 accept_quest()
# ——面板本身不快取報價清單,每次開面板都重新抽,見 TownTavernEvent。同一國同一種委託
# 同時只能有一張進行中,見 has_active_quest(),避免玩家反覆詢問無限疊加。
#
# _ready() 向 WorldTimeStore.controller 註冊每日過期檢查(見 CLAUDE.md「世界時間」):
# 這支 autoload 是 Node、應用程式全程存活,直接傳裸方法參照給 register_day_event() 不會
# 踩 System/time/world_time_controller.gd 開頭提到的 RefCounted 生命週期陷阱(那是
# RefCounted 事件物件才會遇到的問題)。
# =========================================================

signal changed

var quests: Array[Quest] = []


func _ready() -> void:
	WorldTimeStore.controller.register_day_event(_on_day_passed)


## TownTavernEvent「詢問委託」面板開面板前用來檢查每一種委託要不要顯示成「已受理」:
## 同一國同一種委託同時只能有一張進行中,避免玩家反覆詢問無限疊加任務堆獎勵。
func has_active_quest(nation: int, quest_type: int) -> bool:
	return _find_active_quest(nation, quest_type) != null


## 面板按下「接受」時呼叫:offer 是 QuestLibrary.create_offer() 現場生成的報價,直接收下
## 存進清單,不再另外重骰一次——報價清單上看到的內容就是玩家會接到的內容。
func accept_quest(offer: Quest) -> void:
	quests.append(offer)
	changed.emit()


func abandon_quest(quest: Quest) -> void:
	quests.erase(quest)
	changed.emit()


## RoamingEnemyEvent 打贏遊蕩敵人(SELF_WIN)時呼叫,nation 傳那隻敵人的
## party.nation_type(見 RoamingEnemySpawner._nearest_town_nation())。找不到該國進行中的
## 討伐任務時什麼都不做——一般擊退盜賊的金錢/好感度獎勵已經由 Scenes/Battle/battle.gd
## 呼叫 BattleReward.settle_money()/grant_victory_favor() 照常發放,這裡只補發任務額外
## 獎勵。
func notify_bandit_defeated(nation: int) -> void:
	var quest := _find_active_quest(nation, GameEnums.QuestType.BANDIT_SUBJUGATION)
	if quest == null:
		return
	_grant_reward_and_complete(quest)


## 交貨委託是否付得起——Scenes/QuestList/quest_list.gd 的「繳交」按鈕用這個決定要不要
## initial_disabled,不用玩家按下去才發現資源不夠。
func can_complete_delivery(quest: Quest) -> bool:
	return BaseResourceStore.can_afford({quest.resource_type: quest.resource_amount})


## 玩家在任務列表按「繳交」呼叫:先確認付得起再扣資源,付不起回傳 false、不消耗任何
## 東西,呼叫端(quest_list.gd)自己決定要不要跳訊息提示。
func complete_delivery_quest(quest: Quest) -> bool:
	if quest.status != GameEnums.QuestStatus.IN_PROGRESS:
		return false
	if not can_complete_delivery(quest):
		return false
	BaseResourceStore.spend({quest.resource_type: quest.resource_amount})
	_grant_reward_and_complete(quest)
	return true


## Scenes/MapLocation/map_location.gd 進到 TOWN 地點選單時呼叫,destination_nation 傳
## 這座城鎮的 nation——找不到以這座城鎮為目的地、進行中的送信委託時什麼都不做,不限定
## 呼叫端要先自己判斷有沒有,直接每次進城鎮都呼叫即可。
func notify_courier_arrived(destination_nation: int) -> void:
	var quest := _find_active_courier_quest_to(destination_nation)
	if quest == null:
		return
	_grant_reward_and_complete(quest)


## 三種委託共用的完成收尾:標記 COMPLETED(不從清單移除,永久留著當完成紀錄——任務列表
## 對 COMPLETED 不提供任何按鈕,玩家沒有主動清除的管道)、依評級發錢+好感度(跟
## QuestLibrary.description_for() 顯示的數字用同一組 BattleReward 函式,兩邊保證對得上)、
## MessageBar 跳一則提示。委託完成不算重大事件,不寫進 NewsController(見 CLAUDE.md「消息」
## 節)。標記成 COMPLETED 之後 _find_active_quest()/_find_active_courier_quest_to()
## 不會再比對到它,同一張任務不會被重複發獎勵。
func _grant_reward_and_complete(quest: Quest) -> void:
	quest.status = GameEnums.QuestStatus.COMPLETED
	BaseResourceStore.add(GameEnums.ResourceType.GOLD, BattleReward.money_reward_for_rank(quest.rank))
	NationFavorStore.add_favor(quest.nation, BattleReward.favor_for_rank(quest.rank))
	var text := "完成了「%s」委託。" % QuestLibrary.title_for(quest)
	MessageBar.show_message(text)
	changed.emit()


func _find_active_quest(nation: int, quest_type: int) -> Quest:
	for quest in quests:
		if quest.nation == nation and quest.quest_type == quest_type and quest.status == GameEnums.QuestStatus.IN_PROGRESS:
			return quest
	return null


func _find_active_courier_quest_to(destination_nation: int) -> Quest:
	for quest in quests:
		if quest.quest_type == GameEnums.QuestType.COURIER and quest.status == GameEnums.QuestStatus.IN_PROGRESS and quest.destination_nation == destination_nation:
			return quest
	return null


## 每天檢查一次(不是每 frame),跨過 deadline_day 還沒完成的任務改標記逾期,畫面端
## (Scenes/QuestList/quest_list.gd)顯示「已過期」——EXPIRED 跟 COMPLETED 一樣是永久
## 留著的結果紀錄,不提供「放棄」按鈕,只有 IN_PROGRESS 能被玩家主動放棄移除。
func _on_day_passed() -> void:
	var today := WorldTimeStore.controller.world_time.get_day_count()
	var any_expired := false
	for quest in quests:
		if quest.status == GameEnums.QuestStatus.IN_PROGRESS and today > quest.deadline_day:
			quest.status = GameEnums.QuestStatus.EXPIRED
			any_expired = true
	if any_expired:
		changed.emit()


func to_save_data() -> Array:
	var result: Array = []
	for quest in quests:
		result.append({
			"id": quest.id,
			"quest_type": quest.quest_type,
			"category": quest.category,
			"rank": quest.rank,
			"nation": quest.nation,
			"status": quest.status,
			"accepted_day": quest.accepted_day,
			"deadline_day": quest.deadline_day,
			"resource_type": quest.resource_type,
			"resource_amount": quest.resource_amount,
			"destination_nation": quest.destination_nation,
		})
	return result


func load_save_data(data: Array) -> void:
	quests.clear()
	for quest_data in data:
		var quest := Quest.new(
			quest_data.get("id", Util.generate_uuid()),
			quest_data.get("quest_type", GameEnums.QuestType.BANDIT_SUBJUGATION),
			quest_data.get("category", GameEnums.QuestCategory.COMMISSION),
			quest_data.get("rank", GameEnums.RankType.F),
			quest_data.get("nation", GameEnums.BloodlineNation.LION),
			quest_data.get("accepted_day", 0),
			quest_data.get("deadline_day", 0),
			quest_data.get("resource_type", -1),
			quest_data.get("resource_amount", 0),
			quest_data.get("destination_nation", -1)
		)
		quest.status = quest_data.get("status", GameEnums.QuestStatus.IN_PROGRESS)
		quests.append(quest)
