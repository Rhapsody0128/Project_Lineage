extends Node

# =========================================================
# 全域「玩家可操控角色」存取點(autoload,見 project.godot)。
# 跟 PartyStore 不同:這裡是角色池本身(PartyEdit「新增角色」按鈕
# 累積出來的角色,一新增就寫入),PartyStore 才是從這個池子裡挑出來
# 擺盤/組隊的結果(grid/party)。CharacterRoster(角色列表畫面)、
# PartyEdit 候補清單都從這裡取完整角色池,不是各自維護一份。
#
# 這裡只放「可操控」的子集合(未滿 CharacterController.MIN_AGE 的小孩、結婚後的
# 配偶不會進來),完整的全角色池(含小孩/配偶,年紀增長等世界時間事件跑這份)見
# AllCharacterStore。角色滿 MIN_AGE 才會從那邊被加進這裡(見
# WorldTimeEventLibrary._age_up())。
# =========================================================

var all_characteres: Array[Character] = []
