extends Node

# =========================================================
# 玩家全域武器裝備欄(autoload,見 project.godot):六種 GameEnums.WeaponType 各一格,
# 全隊使用同一武器類型的角色共享同一把——武器不是可拾取實體,是類似「全體科技」的概念,
# 換裝(equip())立刻覆蓋舊的一格,沒有庫存。敵人小隊的武器是各自獨立隨機產生
# (PartyController.get_random_party()),不經過這裡。
#
# 玩家角色的加成是「已解析好、複製一份寫進 Character.weapon_stat_bonus/weapon_rank」,
# 不是每次讀 Character.strength 時反查這裡——這樣 Character 保持單純資料容器,存讀檔也
# 不用依賴「WeaponStore 一定要比 CharacterRosterStore 先讀完」這種順序假設。
# =========================================================

## 裝備變更時發出,讓已經開著的鐵匠鋪 UI 能即時刷新。
signal changed

var equipped: Dictionary = {}


func _ready() -> void:
	for weapon_type in GameEnums.WeaponType.values():
		equipped[weapon_type] = WeaponInstance.new(weapon_type, GameEnums.RankType.F, {})


func get_equipped(weapon_type: int) -> WeaponInstance:
	return equipped[weapon_type]


func get_bonus(weapon_type: int, potential_type: int) -> int:
	return equipped[weapon_type].get_point(potential_type)


## 換裝的唯一入口:寫入該武器類型的全域欄位,並推播給目前手持同一武器類型的所有玩家角色。
func equip(weapon_type: int, instance: WeaponInstance) -> void:
	equipped[weapon_type] = instance
	for character in CharacterRosterStore.all_characteres:
		if character.weapon == weapon_type:
			sync_character(character)
	changed.emit()


## 把該角色手持武器類型目前的全域裝備複製一份寫進角色身上——CharacterRosterStore.try_add()
## 新增角色時呼叫一次即可,不用每次讀取素質時反查。
func sync_character(character: Character) -> void:
	var instance: WeaponInstance = equipped[character.weapon]
	character.weapon_rank = instance.rank_type
	character.weapon_stat_bonus = instance.stat_points.duplicate()


func to_save_data() -> Dictionary:
	var data: Dictionary = {}
	for weapon_type in equipped:
		var instance: WeaponInstance = equipped[weapon_type]
		data[str(weapon_type)] = {
			"rank_type": instance.rank_type,
			"stat_points": SaveDataCodec.int_keyed_to_str(instance.stat_points),
		}
	return data


func load_save_data(data: Dictionary) -> void:
	for key in data:
		var weapon_type := int(key)
		var entry: Dictionary = data[key]
		var stat_points := SaveDataCodec.str_keyed_to_int(entry.get("stat_points", {}))
		equipped[weapon_type] = WeaponInstance.new(weapon_type, int(entry.get("rank_type", GameEnums.RankType.F)), stat_points)
	changed.emit()
