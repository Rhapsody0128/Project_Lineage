extends Node

# =========================================================
# 全域奧義使用次數存取點(autoload,見 project.godot)。奧義限制分兩層:
# Ultimate.max_uses_per_battle 管「這場戰鬥最多放幾次」(見 System/ultimate/ultimate.gd),
# 這裡管「同一個奧義(依 Ultimate.id)整個遊戲全程總共能放幾次」——每個奧義各自
# DEFAULT_USES 次,彼此獨立不共用池,兩層限制疊加,施放時必須同時滿足。因為要跨
# Map/Battle 等不同場景切換仍然保留剩餘次數,所以做成 autoload 而不是存在某個
# Party/Battle 身上(那些物件離開場景就沒了)。跟 BattleReportStore/PartyStore
# 一樣屬於 Scenes 層的 session 單例、不是戰鬥規則,所以放在 Scripts/ 而不是 System/——
# 由 Scenes/Battle/battle.gd 讀取/扣減,System/battle/battle.gd 不會直接參照這裡
# (System 不碰 autoload,見 CLAUDE.md)。
# =========================================================

const DEFAULT_USES := 5

## Ultimate.id -> 剩餘次數。未出現過的 id 視為還沒用過,回傳 DEFAULT_USES。
var _uses_remaining: Dictionary = {}

func uses_remaining(ultimate: Ultimate) -> int:
	return _uses_remaining.get(ultimate.id, DEFAULT_USES)

func can_use(ultimate: Ultimate) -> bool:
	return uses_remaining(ultimate) > 0

## 施放成功後呼叫,該奧義用一次少一次,歸零後不會變負數。
func consume(ultimate: Ultimate) -> void:
	_uses_remaining[ultimate.id] = maxi(uses_remaining(ultimate) - 1, 0)


## 祭壇/禁忌祭壇購買奧義用(見 System/base/base_altar.gd),花信仰/詛咒替該奧義的剩餘
## 次數加值——沒有購買次數限制,用完隨時可以再買。
func add_uses(ultimate: Ultimate, amount: int) -> void:
	_uses_remaining[ultimate.id] = uses_remaining(ultimate) + amount


## 存檔用:Ultimate.id 是執行期隨機 UUID(見 ultimate.gd _init()),重開遊戲會變,改用
## 名稱當 key(奧義名稱在 UltimateLibrary 裡本來就唯一,見該檔案 get_by_name())。
func to_save_data() -> Dictionary:
	var result: Dictionary = {}
	for ultimate in UltimateLibrary.build():
		if _uses_remaining.has(ultimate.id):
			result[ultimate.name] = _uses_remaining[ultimate.id]
	return result


func load_save_data(data: Dictionary) -> void:
	_uses_remaining.clear()
	for ultimate_name in data:
		var ultimate := UltimateLibrary.get_by_name(ultimate_name)
		if ultimate != null:
			_uses_remaining[ultimate.id] = int(data[ultimate_name])
