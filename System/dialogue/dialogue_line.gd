class_name DialogueLine
extends RefCounted

## 對話場景的單句台詞。只認 speaker_id 對應到 Dialogue.speakers 裡的 DialogueSpeaker,
## 不直接存物件參照——同一份台詞資料要重播或换角色替換立繪時不會綁死物件實例。
##
## choices 非空時這句是「選擇題」,不再是單純的台詞:Scenes/Dialogue/dialogue_box.gd
## 改成顯示選項按鈕、不接受點擊推進下一句,選幾個選項不限制,見 DialogueChoice。

var speaker_id: String
var text: String
var choices: Array[DialogueChoice]

func _init(p_speaker_id: String, p_text: String, p_choices: Array[DialogueChoice] = []) -> void:
	speaker_id = p_speaker_id
	text = p_text
	choices = p_choices

var has_choices: bool:
	get: return not choices.is_empty()
