class_name Dialogue
extends RefCounted

## 一整段對話場景的資料容器:左右二個頭像站位(side)+ 逐句台詞(lines),由
## Scenes/Dialogue/dialogue_box.gd 逐句播放。同一側不是綁死同一個人——只要
## DialogueSpeaker.side 相同,同一側之後可以換人講話(例如兩位 NPC 先後站左邊),
## 「目前這一句該顯示誰的頭像/名字」「該幫哪一側頭像蓋灰色遮罩」全部由這裡的
## current_speaker_for_side()/is_speaking() 判斷,畫面端不自己比對 speaker_id
## ——比照 Battle 把規則判定留在 System、Scenes 只轉成畫面呈現的分工。

var speakers: Array[DialogueSpeaker]
var lines: Array[DialogueLine]
var current_index: int = 0

func _init(p_speakers: Array[DialogueSpeaker], p_lines: Array[DialogueLine]) -> void:
	speakers = p_speakers
	lines = p_lines

var is_finished: bool:
	get: return current_index >= lines.size()

var current_line: DialogueLine:
	get: return null if is_finished else lines[current_index]

## 呼叫端(Scenes 層)按下/點擊「下一句」時呼叫,回傳播完之後是否還有下一句可看
## (已經是最後一句時回傳 false,呼叫端接著自行收尾關閉對話框)。
func advance() -> bool:
	if is_finished:
		return false
	current_index += 1
	return not is_finished

func get_speaker(speaker_id: String) -> DialogueSpeaker:
	for speaker in speakers:
		if speaker.id == speaker_id:
			return speaker
	return null

## 指定側(LEFT/RIGHT)目前該顯示誰的立繪:從目前這句往回找,最後一次在這側講話
## 的人——不是「這側固定是誰」,同一側換人講話時立繪要跟著換,不能永遠停在第一個
## 站過這側的人身上。
func current_speaker_for_side(side: GameEnums.DialogueSide) -> DialogueSpeaker:
	var index := mini(current_index, lines.size() - 1)
	while index >= 0:
		var line_speaker := get_speaker(lines[index].speaker_id)
		if line_speaker != null and line_speaker.side == side:
			return line_speaker
		index -= 1
	return null

func current_speaker() -> DialogueSpeaker:
	return null if current_line == null else get_speaker(current_line.speaker_id)

## 指定側(LEFT/RIGHT)是不是目前這句的講話人——Scenes 層拿這個決定要不要幫該側
## 頭像蓋灰色遮罩,對比出「這是上一句講話的人,現在輪到另一側了」,而不是自己
## 比對 id。
func is_speaking(side: GameEnums.DialogueSide) -> bool:
	var speaker := current_speaker()
	return speaker != null and speaker.side == side
