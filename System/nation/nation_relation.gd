class_name NationRelation
extends RefCounted

## 國與國之間的邦交狀態查詢。目前遊戲裡沒有任何機制會改變邦交(宣戰/停戰之類的玩法
## 還沒設計),六國兩兩之間一律回傳 GameEnums.NationWarStatus.PEACE——之後如果要做
## 可變的邦交系統,再比照 NationFavorStore 加一個 autoload 存實際狀態,這裡改成查表。

static func get_status(_nation_a: int, _nation_b: int) -> int:
	return GameEnums.NationWarStatus.PEACE
