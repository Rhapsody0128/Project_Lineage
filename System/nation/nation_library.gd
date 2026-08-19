class_name NationLibrary
extends RefCounted

## GameEnums.BloodlineNation 六國的靜態資料集中工廠,比照 BloodlineLibrary 的寫法,
## 呼叫端(UI 等)一律透過這裡取 Nation,不要自己 new Nation.new(id)。

static func get_all() -> Array[Nation]:
	var nations: Array[Nation] = []
	for nation_id in GameEnums.BloodlineNation.values():
		nations.append(Nation.new(nation_id))
	return nations


static func get_by_id(nation_id: int) -> Nation:
	return Nation.new(nation_id)
