extends Node

# =========================================================
# 全域「玩家擁有的全部角色」存取點(autoload,見 project.godot)。
# 跟 PartyStore 不同:這裡是角色池本身(PartyEdit「新增角色」按鈕
# 累積出來的角色,一新增就寫入),PartyStore 才是從這個池子裡挑出來
# 擺盤/組隊的結果(grid/party)。CharacterRoster(角色列表畫面)、
# PartyEdit 候補清單都從這裡取完整角色池,不是各自維護一份。
# =========================================================

var all_heroes: Array[Hero] = []
