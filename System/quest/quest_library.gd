class_name QuestLibrary
extends RefCounted

## 任務生成規則 + 文案,集中在同一個 class(比照 System/event/ 底下各 LocationEvent
## 子類別「文案常數跟流程方法寫在一起」的慣例)。QuestStore(autoload)只負責持有玩家
## 目前的任務清單跟存取,實際「這個國家現在該發哪個等級的任務」查表邏輯在這裡。

## 接下委託到逾期的天數,見 System/time/world_time.gd 的曆法(30 天一個月)——半個月的
## 期限,先用這個當預留位置數值,之後依遊戲數值調整這個常數即可,不用動呼叫端。
const DEADLINE_DAYS := 180

## 交貨委託可能指定的資源種類(排除金錢/詛咒這類不像「貨物」的抽象資源),見
## create_offer() 的 DELIVERY 分支。
const DELIVERY_RESOURCE_TYPES: Array[int] = [
	GameEnums.ResourceType.WOOD, GameEnums.ResourceType.STONE, GameEnums.ResourceType.FOOD,
	GameEnums.ResourceType.ORE, GameEnums.ResourceType.FUR, GameEnums.ResourceType.TOOL,
	GameEnums.ResourceType.BOOK,
]

## 交貨委託的繳交數量,依評級(RankType F~SSS)查表,索引對應 RankType。
const DELIVERY_AMOUNT_BY_RANK: Array[int] = [30, 60, 100, 150, 220, 300, 420, 600, 850]


## 酒館老闆「詢問委託」面板的單張委託生成入口:難度依該國目前的好感度
## (NationFavorRank.rank_for_favor())當基準評級,再透過 RankDrawTable 骰一次個別難度
## (比照 TavernStore 每個候補英雄各自抽一次評級的做法,不是整批套用同一個評級)。
## deadline_day 是生成當下的世界時間天數 + DEADLINE_DAYS,QuestStore 每天用
## WorldTime.get_day_count() 比對這個值判斷是否逾期。
static func create_offer(quest_type: int, nation: int) -> Quest:
	var base_rank := NationFavorRank.rank_for_favor(NationFavorStore.get_favor(nation))
	var rank := RankDrawTable.roll(base_rank)
	var today := WorldTimeStore.controller.world_time.get_day_count()
	var deadline_day := today + DEADLINE_DAYS
	match quest_type:
		GameEnums.QuestType.DELIVERY:
			var resource_type: int = Util.get_random_from_array(DELIVERY_RESOURCE_TYPES)
			var amount: int = DELIVERY_AMOUNT_BY_RANK[rank]
			return Quest.new(Util.generate_uuid(), quest_type, GameEnums.QuestCategory.COMMISSION, rank, nation, today, deadline_day, resource_type, amount)
		GameEnums.QuestType.COURIER:
			var destination := _random_other_nation(nation)
			return Quest.new(Util.generate_uuid(), quest_type, GameEnums.QuestCategory.COMMISSION, rank, nation, today, deadline_day, -1, 0, destination)
		_:
			return Quest.new(Util.generate_uuid(), quest_type, GameEnums.QuestCategory.COMMISSION, rank, nation, today, deadline_day)


static func title_for(quest: Quest) -> String:
	var nation_label := GameEnums.bloodline_nation_label(quest.nation)
	match quest.quest_type:
		GameEnums.QuestType.BANDIT_SUBJUGATION:
			return "討伐%s國周邊強盜" % nation_label
		GameEnums.QuestType.DELIVERY:
			return "%s國物資委託" % nation_label
		GameEnums.QuestType.COURIER:
			return "%s國送信委託" % nation_label
		_:
			return ""


## 任務描述文字,直接引用 BattleReward 的評級對照表算出實際獎勵數字,不另外維護一份
## 任務專屬的獎勵表——任務完成的獎勵發放(見 QuestStore._grant_reward_and_complete())也是
## 呼叫同一組 BattleReward 函式,兩邊數字保證對得上。
static func description_for(quest: Quest) -> String:
	var nation_label := GameEnums.bloodline_nation_label(quest.nation)
	var reward_text := "%d 金錢與 %s 好感度 +%d" % [
		BattleReward.money_reward_for_rank(quest.rank),
		nation_label,
		BattleReward.favor_for_rank(quest.rank),
	]
	match quest.quest_type:
		GameEnums.QuestType.BANDIT_SUBJUGATION:
			return "擊退一隊 %s 國附近的遊蕩強盜,委託完成後獲得 %s。" % [nation_label, reward_text]
		GameEnums.QuestType.DELIVERY:
			return "繳交 %d 個%s,委託完成後獲得 %s。" % [
				quest.resource_amount, GameEnums.resource_string_label(quest.resource_type), reward_text,
			]
		GameEnums.QuestType.COURIER:
			return "將信件送達%s,委託完成後獲得 %s。" % [_town_name_for_nation(quest.destination_nation), reward_text]
		_:
			return ""


## 逾期日期顯示文字,借一個臨時 WorldTime(不是 WorldTimeStore 目前那個時鐘)換算
## deadline_day 對應的年月日,見 System/time/world_time.gd 的 get_display_string()。
static func deadline_text_for(quest: Quest) -> String:
	return WorldTime.new(1.0, float(quest.deadline_day)).get_display_string()


## 送信委託的目的地不能跟委託發放的城鎮同一國,否則「移動到 OO 城」等於原地不動。
static func _random_other_nation(nation: int) -> int:
	var candidates: Array[int] = []
	for candidate in GameEnums.BloodlineNation.values():
		if candidate != nation:
			candidates.append(candidate)
	var picked: int = Util.get_random_from_array(candidates)
	return picked


## 送信委託文案要顯示實際城鎮名稱(例如「雄城」),不是國家名稱本身——六國城鎮名稱不是
## 單純「國家標籤+城」規則命名(見 System/map/map_object.gd 的 get_all()),所以查表找
## 對應這個國家的 TOWN 型別 MapObject,不要自己拼字串。
static func _town_name_for_nation(nation: int) -> String:
	for map_object in MapObject.get_all():
		if map_object.type == GameEnums.MapObjectType.TOWN and map_object.nation == nation:
			return map_object.name
	return GameEnums.bloodline_nation_label(nation)
