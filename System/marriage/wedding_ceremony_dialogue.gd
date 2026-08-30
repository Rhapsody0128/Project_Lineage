class_name WeddingCeremonyDialogue
extends RefCounted

## 結婚成立時共用的婚禮宣誓 Dialogue,告白流程(System/event/town/town_tavern_event.gd)
## 跟聯姻流程(System/event/base/base_marriage_event.gd)在真正確定結婚(骰定成功)的那一刻
## 都呼叫這裡的 build() 取得同一份演出:新郎(左)/新娘(右)輪流宣誓,神父(無頭像,借用左側)
## 收尾「可以親吻新娘了」。播完才輪到呼叫端接手彈新配偶的 CharacterPanel、發結婚 MESSAGE
## (見兩邊呼叫端各自的收尾邏輯,這裡只管演出,不碰 Character 資料/News/MessageBar)。
##
## 名牌(DialogueSpeaker.display_name)跟宣誓詞內文(DialogueLine.text 裡提到自己/對方的
## 名字)刻意用不同格式:名牌兩邊都用 title_full_name(見使用者需求,跟其餘婚姻/告白對話
## 名牌一致);宣誓詞內文兩邊都只用 Character.name(given name,不含姓氏/頭銜)——新人
## 開口念的是名字,不是自己的頭銜。新郎/新娘站位依 Character.gender 決定,不是依
## own/spouse 決定——同性配對(隨機生成的性別池目前偏一律 MALE,見 town_tavern_event.gd
## 檔頭註解)時两人都不是 MALE(或都是 MALE)的邊界情況,退回 own_character 站左當
## 「新郎」順序,只是站位演出上的合理預設,不影響婚姻本身的資料。

const PRIEST_ID := "wedding_priest"
const PRIEST_NAME := "神父"
const KISS_LINE_FORMAT := "%s,你現在可以親吻新娘了。"
const VOW_TEXT_FORMAT := "我，%s，%s你%s為我的合法%s，從今天起，無論是好是壞、是富是窮、生病還是健康，我都將擁有你、持守你，直到死亡將我們分開。如果聖教會允許，我向你發誓我的忠誠。"


static func build(own_character: Character, spouse_character: Character) -> Dialogue:
	# own_character 是 MALE 就當新郎;own_character 不是 MALE 但 spouse_character 是 MALE
	# 時新郎換成 spouse_character;兩人都不是 MALE(或都是 MALE)時退回 own_character
	# 站左當新郎,見檔頭註解。
	var own_is_groom := own_character.gender == GameEnums.Gender.MALE or spouse_character.gender != GameEnums.Gender.MALE
	var groom_character := own_character if own_is_groom else spouse_character
	var bride_character := spouse_character if own_is_groom else own_character

	var groom_speaker := DialogueSpeaker.new(groom_character.id, groom_character.title_full_name, groom_character.face_path, GameEnums.DialogueSide.LEFT)
	var bride_speaker := DialogueSpeaker.new(bride_character.id, bride_character.title_full_name, bride_character.face_path, GameEnums.DialogueSide.RIGHT)
	var priest_speaker := DialogueSpeaker.new(PRIEST_ID, PRIEST_NAME, "", GameEnums.DialogueSide.NARRATOR)

	var lines: Array[DialogueLine] = [
		DialogueLine.new(groom_speaker.id, _vow_text(groom_character.name, bride_character.name, true)),
		DialogueLine.new(bride_speaker.id, _vow_text(bride_character.name, groom_character.name, false)),
		DialogueLine.new(priest_speaker.id, KISS_LINE_FORMAT % groom_character.name),
	]
	return Dialogue.new([groom_speaker, bride_speaker, priest_speaker], lines, GameEnums.WEDDING_CHURCH_BACKGROUND_PATH)


static func _vow_text(speaker_name: String, spouse_name: String, is_groom: bool) -> String:
	var verb := "娶" if is_groom else "嫁"
	var spouse_noun := "妻子" if is_groom else "丈夫"
	return VOW_TEXT_FORMAT % [speaker_name, verb, spouse_name, spouse_noun]
