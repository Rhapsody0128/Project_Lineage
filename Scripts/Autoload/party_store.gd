extends Node

# =========================================================
# 全域小隊編成存取點(autoload,見 project.godot)。跟 BattleReportStore 一樣屬於
# Scenes 層的 session 單例,不是戰鬥規則:只存「從 CharacterRosterStore 角色池裡挑出來
# 組隊/擺盤」的結果,不是角色池本身(那個是 CharacterRosterStore.all_characteres)。
#
# grid/party 要等玩家按下「完成編輯」才會寫入——編輯中的每一步拖曳/擺放
# 只留在 PartyEdit 場景自己的草稿(見 party_edit.gd 的 grid,拿 PartyStore.grid
# clone() 出來的獨立副本編輯),不會即時反映到這裡,避免其他場景讀到還沒定案
# 的擺盤。grid 是那次「完成編輯」當下的網格快照(重進 PartyEdit 場景時拿來還原
# 擺盤用),party 是同一時刻轉換出的 Party 物件(供其他場景直接使用)。
# =========================================================

var grid: PartyEditGrid = null
var party: Party = null

func save_party(p_party: Party) -> void:
	party = p_party


## 存檔用:party/grid 兩份一起打包,見 Scripts/save_data_codec.gd(grid 的站位其實跟
## party.battle_cost_positions 是同一份資料,不重複存)。
func to_save_data() -> Dictionary:
	return {
		"party": SaveDataCodec.encode_party(party),
		"grid": SaveDataCodec.encode_party_grid(grid),
	}


## 讀檔用:by_id 是 AllCharacterStore.load_save_data() 回傳的 id → Character 對照表。
func load_save_data(data: Dictionary, by_id: Dictionary) -> void:
	party = SaveDataCodec.decode_party(data.get("party", {}), by_id)
	grid = SaveDataCodec.decode_party_grid(data.get("grid", {}), party, by_id)
