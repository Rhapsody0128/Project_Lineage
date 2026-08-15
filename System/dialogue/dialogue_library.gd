class_name DialogueLibrary
extends RefCounted

## 對話資料集中定義,比照 SkillLibrary/MapObjectData.get_all() 的作法——之後正式的
## 劇情對話會依事件/地點各自加一個 build_xxx() 靜態工廠,不要把台詞內容散落寫在
## Scenes 層腳本裡。目前先提供一份 demo 對話供 Scenes/Dialogue/dialogue_box.tscn 測試用。

static func build_demo() -> Dialogue:
	var left := DialogueSpeaker.new("demo_a", "艾莉婭", FaceController.get_random_face_path(), GameEnums.DialogueSide.LEFT)
	var right := DialogueSpeaker.new("demo_b", "肯特", FaceController.get_random_face_path(), GameEnums.DialogueSide.RIGHT)

	var lines: Array[DialogueLine] = [
		DialogueLine.new(left.id, "邊境城最近不太平靜,你有聽說什麼消息嗎?"),
		DialogueLine.new(right.id, "聽說是鄰國的斥候,不過還沒確認。"),
		DialogueLine.new(left.id, "如果真的開戰,我們得先把小隊編成準備好。"),
	]

	return Dialogue.new([left, right], lines)


## 城堡選單「城堡」按鈕用(見 Scenes/MapLocation/map_location.gd):守衛擋在門口,
## 玩家選「闖進去」、選「離開」回原本場景——場景路徑一律由呼叫端傳入(不寫死在
## System/,見 DialogueChoice 的註解)。「闖進去」不直接切場景(next_scene_path 傳空
## 字串),改由 on_challenge_accepted(呼叫端傳入)彈出 AskBattle 詢問是否跳過戰鬥,
## 再依玩家選擇決定去哪個場景,DialogueLibrary 本身不碰 Scenes 層的 autoload。
##
## self_party 可能是 null(玩家還沒去 PartyEdit 按過「完成編輯」,沒有真正屬於他的隊伍)——
## 這種情況不生一支假的隨機小隊頂替,直接不給「闖進去」選項,只能「離開」,守衛台詞
## 也換成請玩家先去整隊。
static func build_castle_gate_challenge(leave_scene_path: String, self_party: Party, on_challenge_accepted: Callable) -> Dialogue:
	var has_party := self_party != null
	var player := self_party.leader if has_party else HeroController.get_random_hero()
	var guard := HeroController.get_random_hero()

	var player_speaker := DialogueSpeaker.new(player.id, player.full_name, player.face_path, GameEnums.DialogueSide.LEFT)
	var guard_speaker := DialogueSpeaker.new(guard.id, guard.full_name, guard.face_path, GameEnums.DialogueSide.RIGHT)

	var lines: Array[DialogueLine] = []

	if has_party:
		var choices: Array[DialogueChoice] = [
			DialogueChoice.new("闖進去", "", on_challenge_accepted),
			DialogueChoice.new("離開", leave_scene_path),
		]
		lines = [
			DialogueLine.new(guard_speaker.id, "站住,沒有許可不准進入。"),
			DialogueLine.new(player_speaker.id, "", choices),
		]
	else:
		var choices: Array[DialogueChoice] = [
			DialogueChoice.new("離開", leave_scene_path),
		]
		lines = [
			DialogueLine.new(guard_speaker.id, "站住,沒有許可不准進入。"),
			DialogueLine.new(player_speaker.id, "（我還沒整頓好隊伍,先回去編隊吧。）", choices),
		]

	return Dialogue.new([guard_speaker, player_speaker], lines)


## 大地圖地點選單「聊天」按鈕用(見 Scenes/MapLocation/map_location.gd):隨機生一位
## Hero 當作聊天對象,先只給一句招呼詞佔位——之後要接真的劇情對話再依地點/角色另外
## 加 build_xxx() 工廠,不要回頭改這個函式的用途。
static func build_random_npc_chat() -> Dialogue:
	var player := HeroController.get_random_hero()
	var npc := HeroController.get_random_hero()
	var npc2 := HeroController.get_random_hero()

	var player_speaker := DialogueSpeaker.new(player.id, player.full_name, player.face_path, GameEnums.DialogueSide.LEFT)
	var npc_speaker := DialogueSpeaker.new(npc.id, npc.full_name, npc.face_path, GameEnums.DialogueSide.RIGHT)
	var npc2_speaker := DialogueSpeaker.new(npc2.id, npc2.full_name, npc2.face_path, GameEnums.DialogueSide.RIGHT)
	var lines: Array[DialogueLine] = [
		DialogueLine.new(player_speaker.id, "你好,這附近有什麼特別的事嗎?"),
		DialogueLine.new(npc_speaker.id, "你好,異鄉人。這裡最近沒什麼特別的事。"),
		DialogueLine.new(npc2_speaker.id, "別多嘴,現在說甚麼都有可能出事。"),
	]
	return Dialogue.new([npc_speaker, npc2_speaker, player_speaker], lines)
