extends Node

# =========================================================
# 存檔/讀檔總協調點(autoload,見 project.godot)。跟 BattleReportStore/PartyStore 一樣
# 屬於 Scenes 層的 session 基礎設施,不是規則邏輯,所以放 Scripts/Autoload/ 不放 System/。
#
# 只負責「收集每個 store 的 to_save_data() 打包寫檔」/「讀檔後依序餵回每個 store 的
# load_save_data()」,不自己碰任何 store 的內部欄位——複雜的物件參照還原(Character
# 的 parent/mate/children 圖、Skill/Ultimate 名稱換物件)集中在 Scripts/save_data_codec.gd,
# 這裡只負責排順序跟檔案 I/O。
#
# 讀檔的呼叫順序有依賴關係,不能打亂:AllCharacterStore 要最先讀(它是唯一真正重建
# Character 物件的地方,回傳 id → Character 對照表),CharacterRosterStore/PartyStore
# 只存 id,要靠這份對照表換回實際物件參照,必須排在後面。其餘 store 彼此獨立,順序
# 不影響正確性。
#
# 存檔位固定 3 個(SLOT_COUNT),存成 user://saves/slot_N.json——JSON 而非 Godot
# 內建的 Resource/var_to_bytes 序列化,是因為存檔格式要能長期演進(欄位增減、跨版本
# 相容),JSON 是純資料格式,不會綁死目前的 class 定義;byte 序列化改了 class 定義
# 就可能讀不回來。
# =========================================================

const SAVE_DIR := "user://saves/"
const SLOT_COUNT := 3


func _slot_path(slot: int) -> String:
	return "%sslot_%d.json" % [SAVE_DIR, slot]


func has_save(slot: int) -> bool:
	return FileAccess.file_exists(_slot_path(slot))


## 存檔選單列表用的摘要資訊(世界時間/存檔時間),只解析 JSON 頂層欄位,不會真的
## 觸發任何 store 的還原邏輯。空字典代表這個存檔位還沒有存檔。
func get_slot_summary(slot: int) -> Dictionary:
	if not has_save(slot):
		return {}
	var file := FileAccess.open(_slot_path(slot), FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return {}
	return {
		"saved_at": parsed.get("saved_at", ""),
		"world_time_display": parsed.get("world_time_display", ""),
	}


func save_game(slot: int) -> bool:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)

	var data := {
		"version": 1,
		"saved_at": Time.get_datetime_string_from_system(),
		"world_time_display": WorldTimeStore.get_display_string(),
		"characters": AllCharacterStore.to_save_data(),
		"roster_ids": CharacterRosterStore.to_save_data(),
		"party_store": PartyStore.to_save_data(),
		"base_resources": BaseResourceStore.to_save_data(),
		"building_progress": BaseBuildingProgressStore.to_save_data(),
		"dispatch": BaseDispatchStore.to_save_data(),
		"nation_favors": NationFavorStore.to_save_data(),
		"world_time": WorldTimeStore.to_save_data(),
		"ultimate_uses": UltimateStore.to_save_data(),
		"workshop_recipe": WorkshopRecipeStore.to_save_data(),
		"exchange_orders": BaseExchangeStore.to_save_data(),
		"unlocked_tech_ids": TechStore.to_save_data(),
		"barracks_training": BarracksTrainingStore.to_save_data(),
		"news_entries": NewsStore.to_save_data(),
		"map_session": MapSessionStore.to_save_data(),
	}

	var file := FileAccess.open(_slot_path(slot), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	return true


func load_game(slot: int) -> bool:
	if not has_save(slot):
		return false
	var file := FileAccess.open(_slot_path(slot), FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return false
	var data: Dictionary = parsed

	var by_id: Dictionary = AllCharacterStore.load_save_data(data.get("characters", []))
	CharacterRosterStore.load_save_data(data.get("roster_ids", []), by_id)
	PartyStore.load_save_data(data.get("party_store", {}), by_id)
	BaseResourceStore.load_save_data(data.get("base_resources", {}))
	BaseBuildingProgressStore.load_save_data(data.get("building_progress", {}))
	BaseDispatchStore.load_save_data(data.get("dispatch", {}))
	NationFavorStore.load_save_data(data.get("nation_favors", {}))
	WorldTimeStore.load_save_data(data.get("world_time", {}))
	UltimateStore.load_save_data(data.get("ultimate_uses", {}))
	WorkshopRecipeStore.load_save_data(data.get("workshop_recipe", "wood"))
	BaseExchangeStore.load_save_data(data.get("exchange_orders", {}))
	TechStore.load_save_data(data.get("unlocked_tech_ids", []))
	BarracksTrainingStore.load_save_data(data.get("barracks_training", {}))
	NewsStore.load_save_data(data.get("news_entries", []))
	MapSessionStore.load_save_data(data.get("map_session", {}))
	return true
