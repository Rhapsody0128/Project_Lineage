class_name TroopController
extends RefCounted

## 軍團底下小隊數量,之後會是可被科技研發提升的變數,目前先固定 1 個
const RANDOM_PARTY_COUNT := 1

static func get_random_troop() -> Troop:
	var parties: Array[Party] = []
	for i in range(RANDOM_PARTY_COUNT):
		parties.append(PartyController.get_random_party())
	return Troop.new("隨機軍團", parties)
