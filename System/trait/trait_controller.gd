class_name TraitController
extends RefCounted

## 從個性池中隨機抽 count 個不重複的個性(池子資料見 TraitLibrary.build())
static func get_random_traits(count: int) -> Array[Trait]:
	var pool := TraitLibrary.build()
	pool.shuffle()
	var result: Array[Trait] = []
	for i in range(min(count, pool.size())):
		result.append(pool[i])
	return result
