extends Node

# =========================================================
# 全域「整團領導人」存取點(autoload,見 project.godot)——代表玩家對外開口說話/交涉的
# 那位角色(見大地圖各 LocationEvent 的玩家方 DialogueSpeaker),跟 Party.leader
# (戰場隊長,只用來在戰鬥格站位/金色標記與判斷隊長陣亡即結束戰鬥,見 System/party/
# party.gd 開頭註解)完全脫鉤,分屬不同職責——一個管「誰代表整團開口」,一個管「誰在
# 戰場上扛隊長」,互不影響。選人範圍是全部角色池(CharacterRosterStore.all_characteres),
# 不限定要編入目前小隊(見 Scenes/Base/base_action_panel.gd 的 _open_leader_picker())。
# =========================================================

## 玩家明確指定的領導人;null,或指定的角色已解雇/過世時,get_leader() 退回預設主角
## (CharacterController.get_fixed_protagonist() 建立、is_protagonist == true 的那位)。
var leader: Character = null


func set_leader(character: Character) -> void:
	leader = character


func get_leader() -> Character:
	if leader != null and not leader.is_dead and not leader.is_dismissed:
		return leader
	return _find_protagonist()


func _find_protagonist() -> Character:
	for character in CharacterRosterStore.all_characteres:
		if character.is_protagonist:
			return character
	return null


## 存檔用:只存 id——完整角色資料已經在 AllCharacterStore 那份存過一次(見
## Scripts/Autoload/character_roster_store.gd 同一套慣例)。leader 為 null 時
## (玩家從未手動指定過,一直吃 get_leader() 的主角預設值)存空字串。
func to_save_data() -> Dictionary:
	return {"leader_id": leader.id if leader != null else ""}


## 讀檔用:by_id 是 AllCharacterStore.load_save_data() 回傳的 id → Character 對照表,
## 必須先讀完 AllCharacterStore 才能呼叫這裡。
func load_save_data(data: Dictionary, by_id: Dictionary) -> void:
	var leader_id: String = data.get("leader_id", "")
	leader = by_id.get(leader_id, null) if leader_id != "" else null
