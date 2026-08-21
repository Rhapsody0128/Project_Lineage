extends Node

# =========================================================
# 根據地「每棟建築目前等級/建造中/升級中」(autoload,見 project.godot)。跟
# BaseResourceStore/BaseDispatchStore 同一套慣例:這是 Scenes 層的 session 狀態(玩家
# 目前進度),不是規則邏輯——規則(建造/升級要花多少資源跟天數、容量怎麼算)集中在這裡
# 的存取方法,實際數字在 Building.build_cost/build_days/upgrade_costs/upgrade_days
# (見 System/base/building/building_library.gd)。
#
# 用 GameEnums.BuildingType(Building.type)當 key,不是字串——17 種建築類型本來就
# 一一對應,不需要另外維護一份 id,見 System/base/building/building.gd 開頭註解。
#
# 等級 0 表示尚未建造(DISABLED,查不到 type 時的預設值),1~9 對應 GameEnums.RankType
# 的 F~SSS。容納工作角色人數 = 等級本身,不用另開容量表。
#
# 0→1 級叫「建造」(start_construction()),1 級以上叫「升級」(start_upgrade())——兩者
# 都要花天數,差別是建造完成前 0 級完全不能用,升級中則維持目前等級正常運作/正常派遣
# 產出(_levels 要等天數倒數完才真的 +1,期間 get_level()/get_rank() 讀到的還是目前
# 等級,不會被升級中的「目標等級」影響)。
#
# _ready() 向 WorldTimeStore.controller 註冊每日結算(見 CLAUDE.md「世界時間」):這支
# autoload 是 Node、應用程式全程存活,直接傳裸方法參照給 register_day_event() 不會踩
# System/time/world_time_controller.gd 開頭提到的 RefCounted 生命週期陷阱(那是
# RefCounted 事件物件才會遇到的問題)。這是天數倒數,跟 BaseDispatchStore 的月結算
# (register_month_event)是不同週期,各自獨立註冊。
# =========================================================

signal changed

var _levels: Dictionary = {}
## building_type -> 建造剩餘天數,只在「0 級、建造中」時存在。
var _construction: Dictionary = {}
## building_type -> 升級剩餘天數,只在「已建成、升級中」時存在。
var _upgrades: Dictionary = {}
## building_type -> 是否啟動生產(玩家可在 ActionPanel 標題列的開關鈕手動關閉,見
## Scenes/Base/base_action_panel.gd),缺值視為 true(預設啟動)。關閉的建築
## BaseDispatchStore 月結算會整棟跳過(不產出、不消耗、角色也不會拿到派遣經驗)。
var _active: Dictionary = {}


func _ready() -> void:
	WorldTimeStore.controller.register_day_event(_on_day_passed)


func get_level(building_type: GameEnums.BuildingType) -> int:
	return _levels.get(building_type, 0)


func is_unlocked(building_type: GameEnums.BuildingType) -> bool:
	return get_level(building_type) > 0


func get_max_workers(building_type: GameEnums.BuildingType) -> int:
	return get_level(building_type)


func is_active(building_type: GameEnums.BuildingType) -> bool:
	return _active.get(building_type, true)


func set_active(building_type: GameEnums.BuildingType, active: bool) -> void:
	_active[building_type] = active
	changed.emit()


## 城鎮中心等級決定其他 16 棟建築的等級上限(見「根據地內政系統設計」文件二節):城鎮中心
## Lv0 時其他建築 effective_max_level = 0,連 0→1 建造都不能開始;城鎮中心本身不受這條
## 限制,直接回傳自己的 max_level()。
func effective_max_level(building: Building) -> int:
	if building.type == GameEnums.BuildingType.STRONGHOLD:
		return building.max_level()
	return mini(building.max_level(), get_level(GameEnums.BuildingType.STRONGHOLD))


## 角色總容量(招募/婚生子女的總數上限,跟戰場出戰人數上限是不同概念,見
## AllCharacterStore)= 20 + 20×住宅等級,頂到 Lv9 的 200。
func get_character_capacity() -> int:
	return 20 + 20 * get_level(GameEnums.BuildingType.RESIDENTIAL)


## 回傳 GameEnums.RankType,0 級(尚未建成)回傳 -1,呼叫端要先用 is_unlocked() 判斷。
func get_rank(building_type: GameEnums.BuildingType) -> int:
	return get_level(building_type) - 1


func is_constructing(building_type: GameEnums.BuildingType) -> bool:
	return _construction.has(building_type)


func get_construction_days_remaining(building_type: GameEnums.BuildingType) -> int:
	return _construction.get(building_type, 0)


func can_build(building: Building) -> bool:
	return (
		get_level(building.type) == 0
		and not is_constructing(building.type)
		and effective_max_level(building) >= 1
	)


## 資材不足或無法建造(已建成/建造中)都回傳 false 且不扣款,呼叫端(Scenes/Base/base_action_panel.gd)
## 用回傳值決定要不要顯示「資材不足」提示。
func start_construction(building: Building) -> bool:
	if not can_build(building):
		return false
	if not BaseResourceStore.can_afford(building.build_cost):
		return false
	BaseResourceStore.spend(building.build_cost)
	_construction[building.type] = building.build_days
	changed.emit()
	return true


func is_upgrading(building_type: GameEnums.BuildingType) -> bool:
	return _upgrades.has(building_type)


func get_upgrade_days_remaining(building_type: GameEnums.BuildingType) -> int:
	return _upgrades.get(building_type, 0)


func can_upgrade(building: Building) -> bool:
	var level := get_level(building.type)
	return level > 0 and level < effective_max_level(building) and not is_upgrading(building.type)


## can_upgrade() 為 false 回傳空字典/0。
func get_upgrade_cost(building: Building) -> Dictionary:
	if not can_upgrade(building):
		return {}
	return building.upgrade_costs[get_level(building.type) - 1]


func get_upgrade_days(building: Building) -> int:
	if not can_upgrade(building):
		return 0
	return building.upgrade_days[get_level(building.type) - 1]


## 資材不足或無法升級(未建成/已滿級/升級中)都回傳 false 且不扣款。升級開始不會馬上
## 加等級——_levels 要等天數倒數完(見 _on_day_passed())才真的 +1,期間建築維持目前
## 等級正常運作,不會停擺。
func start_upgrade(building: Building) -> bool:
	if not can_upgrade(building):
		return false
	var cost := get_upgrade_cost(building)
	if not BaseResourceStore.can_afford(cost):
		return false
	BaseResourceStore.spend(cost)
	_upgrades[building.type] = get_upgrade_days(building)
	changed.emit()
	return true


func to_save_data() -> Dictionary:
	return {
		"levels": SaveDataCodec.int_keyed_to_str(_levels),
		"construction": SaveDataCodec.int_keyed_to_str(_construction),
		"upgrades": SaveDataCodec.int_keyed_to_str(_upgrades),
		"active": SaveDataCodec.int_keyed_to_str(_active),
	}


func load_save_data(data: Dictionary) -> void:
	_levels = SaveDataCodec.str_keyed_to_int(data.get("levels", {}))
	_construction = SaveDataCodec.str_keyed_to_int(data.get("construction", {}))
	_upgrades = SaveDataCodec.str_keyed_to_int(data.get("upgrades", {}))
	_active = SaveDataCodec.str_keyed_to_int(data.get("active", {}))
	changed.emit()


func _on_day_passed() -> void:
	for building_type in _construction.keys():
		_construction[building_type] -= 1
		if _construction[building_type] <= 0:
			_construction.erase(building_type)
			_levels[building_type] = 1
			changed.emit()

	for building_type in _upgrades.keys():
		_upgrades[building_type] -= 1
		if _upgrades[building_type] <= 0:
			_upgrades.erase(building_type)
			_levels[building_type] = get_level(building_type) + 1
			changed.emit()
