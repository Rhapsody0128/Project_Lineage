class_name TravelEventLibrary
extends RefCounted

## 大地圖移動中隨機觸發的旅行事件清單。TravelEventRoller(見
## System/map/travel_event_roller.gd)骰到要觸發時呼叫 trigger_random(),之後新增旅行
## 事件只要在 _POOL 多塞一個 Callable,不用改 TravelEventRoller 或呼叫端 map.gd。

static func trigger_random(player_pos: Vector2) -> void:
	var pool: Array[Callable] = [
		func(): WildAnimalAttackEvent.trigger(player_pos),
		func(): TravelerReliefEvent.trigger(player_pos),
		func(): LostChildEvent.trigger(player_pos),
	]
	var picked: Callable = Util.get_random_from_array(pool)
	picked.call()
