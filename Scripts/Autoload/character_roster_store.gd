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

## 角色列已滿時提示玩家的訊息(見 try_add())——文案集中寫在這個共用層,不要讓每個
## 呼叫端各自維護一份相同的字串,比照 AskBattle 把固定文案內建在彈窗本身的寫法。
const ROSTER_FULL_MESSAGE := "角色已達上限，請前往角色列表解雇角色騰出空位。"


## 玩家角色列的唯一新增入口:先確保寫進 AllCharacterStore(角色總容量的唯一把關點,
## 見該檔案 register()),成功才真的加進這裡的 all_characteres,回傳是否加入成功。
## 任何要把角色加進玩家角色列的地方(招募/PartyEdit「新增角色」/小孩成年,見
## TownTavernEvent._on_recruit_hero_selected()、party_edit.gd
## _on_add_character_pressed()、WorldTimeEventLibrary._age_up())都要走這裡,不要
## 自己各自呼叫 AllCharacterStore.register() + all_characteres.append()——是否已滿的
## 判斷跟提示集中在這一個入口,不用每個呼叫端各自處理「滿了要幹嘛」。容量已滿時不
## 靜默失敗,直接用 MessageBar 提示玩家去角色列表解雇角色騰位置,不彈跳頁面/彈窗,
## 呼叫端只要看回傳值決定自己那邊的 UI 要不要跟著反應(例如按鈕維持可按,讓玩家騰出
## 空位後可以直接再按一次)。
func try_add(character: Character) -> bool:
	if all_characteres.has(character):
		return true
	if not AllCharacterStore.register(character):
		MessageBar.show_message(ROSTER_FULL_MESSAGE)
		return false
	all_characteres.append(character)
	WeaponStore.sync_character(character)
	return true


## 存檔用:只存 id——完整角色資料已經在 AllCharacterStore 那份存過一次,這裡只需要
## 記錄「這批 id 是玩家可操控子集合」。
func to_save_data() -> Array:
	var ids: Array = []
	for character in all_characteres:
		ids.append(character.id)
	return ids


## 讀檔用:by_id 是 AllCharacterStore.load_save_data() 回傳的 id → Character 對照表,
## 必須先讀完 AllCharacterStore 才能呼叫這裡。
func load_save_data(ids: Array, by_id: Dictionary) -> void:
	all_characteres.clear()
	for character_id in ids:
		if by_id.has(character_id):
			all_characteres.append(by_id[character_id])
