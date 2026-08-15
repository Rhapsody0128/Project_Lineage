extends Node

# =========================================================
# 全域小隊編成存取點(autoload,見 project.godot)。跟 BattleReportStore 一樣屬於
# Scenes 層的 session 單例,不是戰鬥規則:all_heroes 是 PartyEdit「新增角色」
# 按鈕累積出來的角色池,一新增就寫入,供其他場景取用完整角色池。
#
# grid/party 則要等玩家按下「完成編輯」才會寫入——編輯中的每一步拖曳/擺放
# 只留在 PartyEdit 場景自己的草稿(見 party_edit.gd 的 grid,拿 PartyEditStore.grid
# clone() 出來的獨立副本編輯),不會即時反映到這裡,避免其他場景讀到還沒定案
# 的擺盤。grid 是那次「完成編輯」當下的網格快照(重進 PartyEdit 場景時拿來還原
# 擺盤用),party 是同一時刻轉換出的 Party 物件(供其他場景直接使用)。
# =========================================================

var all_heroes: Array[Hero] = []
var grid: PartyEditGrid = null
var party: Party = null

func save_party(p_party: Party) -> void:
	party = p_party
