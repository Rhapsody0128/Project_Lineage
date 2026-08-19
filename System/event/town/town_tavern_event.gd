class_name TownTavernEvent
extends LocationEvent

## 酒館事件,見 Scenes/MapLocation/map_location.gd「酒館」按鈕:進門後只有
## ENCOUNTER_CHANCE_PERCENT(10%)機率遇到異鄉人(stranger)向玩家角色池裡符合資格
## (見 MarriageRule.can_propose())的其中一位角色搭訕,直接進入告白流程的「被告白」
## 情境(MarriageProposal 的 INCOMING 模式)。角色池裡沒有任何符合資格的角色時,只播
## 一句佔位反應句,不進告白畫面。
##
## 不管有沒有遇到搭訕(沒骰中/骰中但沒人符合資格/告白流程跑完任何一種結局),最後
## 都會接到酒館老闆(bartender,見 _goto_bartender_after())的招呼台詞,播完不用玩家
## 額外選擇,直接彈出 ActionPanel(Scenes/ActionPanel/action_panel.gd)列出一批隨機英雄
## 供招募進 CharacterRosterStore——招募不會關閉面板,那一列的按鈕改成 disabled(見
## ActionPanelItem.disable_after_select),玩家可以在同一次彈窗裡連續招募好幾位,按 ×
## 才離開、回到觸發事件時記下的地點選單場景。搭訕反應對話跟酒館老闆招呼詞合併成同一個
## Dialogue 播放(見 _goto_bartender_after()),不是切兩次場景;彈出 ActionPanel 靠
## goto_dialogue() 的 on_finished 參數(對話播完的通知,不是玩家點出來的選項),
## next_scene_path 留空讓對話畫面留在背景,ActionPanel 疊加在上面,不需要真的切場景。
##
## CharacterController.get_random_character() 目前只有男性姓名庫,一律指派 MALE
## (見該檔案註解,女性角色池尚未建立),所以「性別相反」條件實務上要等女性角色池
## 補上才會常態成立——這是既有限制,不是這個事件本身的問題。
##
## 玩家在 MarriageProposal 按下「接受」/「婉拒」後的結果,以及最終要不要寫入
## Character.mate,都由這個事件的 _on_proposal_result() 收尾決定,MarriageProposal
## 場景本身不寫任何角色資料(見 System/marriage/marriage_proposal_request.gd)。
##
## 「接受」後還有一輪成功率判定(見 MarriageRule.roll_acceptance()):玩家在
## MarriageProposal 清單裡選的人正是 stranger 屬意的 courted 時 100% 成功。玩家也可以
## 改選別人上場反告白(= 不讓 stranger 屬意的 courted 出面接受),這種情況只有 20%
## 成功率,沒骰中就是真的告白失敗,不會再補救;若一開始就按「婉拒」則完全不骰,
## 直接播婉拒台詞收尾。

const MARRIAGE_PROPOSAL_SCENE_PATH := "res://Scenes/Marriage/marriage_proposal.tscn"
const BACKGROUND_PATH := "res://Images/Dialogue/Town/town_tavern.png"

## 進酒館遇到異鄉人搭訕的機率(百分比),沒骰中直接跳去酒館老闆招呼詞。
const ENCOUNTER_CHANCE_PERCENT := 100

const BARTENDER_ID := "tavern_bartender"
const BARTENDER_NAME := "酒館老闆"
const BARTENDER_GREETING := "你好,有甚麼需要的嗎?"

## ActionPanel 一次列出幾位隨機英雄供招募,見 _open_recruit_panel()。
const RECRUIT_HERO_COUNT := 10
const RECRUIT_PANEL_TITLE := "酒館老闆介紹的旅人"
const RECRUIT_BUTTON_LABEL := "招募"

var stranger: Character
var courted: Character
var _return_scene_path: String
var _bartender_face_path: String


static func trigger(return_scene_path: String) -> void:
	var event := TownTavernEvent.new()
	event._start(return_scene_path)


func _start(return_scene_path: String) -> void:
	_return_scene_path = return_scene_path
	var bartender_gender = Util.get_random_from_array([GameEnums.Gender.MALE, GameEnums.Gender.FEMALE])
	_bartender_face_path = FaceController.get_random_face_path(bartender_gender)

	if Util.get_random_float(0.0, 100.0) >= ENCOUNTER_CHANCE_PERCENT:
		_goto_bartender_after(Dialogue.new([], [], BACKGROUND_PATH))
		return

	stranger = CharacterController.get_random_character(GameEnums.RankType.F)

	var eligible: Array[Character] = []
	for character in CharacterRosterStore.all_characteres:
		if MarriageRule.can_propose(character, stranger):
			eligible.append(character)

	if eligible.is_empty():
		_goto_bartender_after(_build_no_one_available())
		return

	courted = Util.get_random_from_array(eligible)
	var request := MarriageProposalRequest.new(courted, stranger, GameEnums.ProposalMode.INCOMING)
	# 不能直接傳裸方法參照 _on_proposal_result——event 是 RefCounted,裸方法參照
	# 底層只存 ObjectID,不會讓引用計數增加,_start() 一返回、trigger() 的區域變數
	# event 失去參照就會立刻被釋放,玩家在 MarriageProposal 按下按鈕時這個 callback
	# 早就失效了(Callable.is_valid() 悄悄回傳 false,不會報錯,只會直接 fallback
	# 回 NavigationStore.go_back(),很難察覺)。包一層 lambda 讓它捕捉 self,才會靠
	# Variant 的 Ref<RefCounted> 語意撐住 event 活到玩家真正按下按鈕的那一刻。
	SceneHandoffStore.queue(MarriageProposalRequest.MAILBOX_KEY, request, "", func(accepted: bool, self_character: Character, target_character: Character) -> void:
		_on_proposal_result(accepted, self_character, target_character)
	)
	goto_dialogue(_build_approach(), MARRIAGE_PROPOSAL_SCENE_PATH)


## 單句台詞沒有選項,播完由 goto_dialogue() 傳的 next_scene_path 自動接手轉場到
## 告白畫面,跟 town_chat_event.gd 的寫法一致。
func _build_approach() -> Dialogue:
	var stranger_speaker := DialogueSpeaker.new(stranger.id, stranger.full_name, stranger.face_path, GameEnums.DialogueSide.RIGHT)
	var courted_speaker := DialogueSpeaker.new(courted.id, courted.full_name, courted.face_path, GameEnums.DialogueSide.LEFT)
	var lines: Array[DialogueLine] = [
		DialogueLine.new(stranger_speaker.id, "請問...",),
		DialogueLine.new(stranger_speaker.id, "我可以請你喝一杯嗎?",),
		DialogueLine.new(courted_speaker.id, "這...",),
	]
	return Dialogue.new([stranger_speaker, courted_speaker], lines, BACKGROUND_PATH)


func _build_no_one_available() -> Dialogue:
	var stranger_speaker := DialogueSpeaker.new(stranger.id, stranger.full_name, stranger.face_path, GameEnums.DialogueSide.RIGHT)
	var lines: Array[DialogueLine] = [
		DialogueLine.new(stranger_speaker.id, "請問..."),
		DialogueLine.new(stranger_speaker.id, "...不好意思,認錯人了。"),
	]
	return Dialogue.new([stranger_speaker], lines, BACKGROUND_PATH)


## MarriageProposal 場景按下「接受」/「婉拒」後呼叫:self_character 是玩家最終選的
## 人(不一定是 courted,見 marriage_proposal.gd 的清單選人邏輯),target_character
## 固定是 stranger。婉拒完全不骰,直接播婉拒台詞;接受則交給 _resolve_acceptance()
## 判定成功率、寫入 mate、決定分支對話,兩種結果最後都接到 _goto_bartender_after()。
##
## 婉拒台詞開口的一律是 courted(被告白的人,自始被 stranger 搭訕的對象),不是
## self_character(玩家在清單裡當下選的人)——選了別人只是玩家瀏覽/預覽,沒有
## 真的接受求婚,開口回絕的人選不會因為玩家點了誰而改變。
func _on_proposal_result(accepted: bool, self_character: Character, target_character: Character) -> void:
	if accepted:
		_resolve_acceptance(self_character, target_character)
	else:
		_goto_bartender_after(_build_declined_reaction(courted))


## picked 是否正是 stranger 屬意的 courted,決定告白基礎成功率是 100% 還是 20%
## (見 MarriageRule.roll_acceptance())。骰中依 picked 是不是 courted 分兩種成親對話
## (courted 本人接受 vs. courted 引薦 picked 上場、stranger 也接受);選了別人反告白
## 又沒骰中時,就是真的告白失敗,不寫入 mate,劇情文案見 _build_rejected_reaction()。
func _resolve_acceptance(picked: Character, stranger_character: Character) -> void:
	if MarriageRule.roll_acceptance(picked, courted):
		picked.marry(stranger_character)
		# stranger_character 是 CharacterController.get_random_character() 生成的一次性
		# NPC,結婚前不屬於玩家任何角色池;成親後變成配偶,年紀要跟著世界時間增長
		# (見 WorldTimeEventLibrary._age_up()),但配偶依設計不進 CharacterRosterStore
		# (不可操控/上場),所以只註冊進 AllCharacterStore。
		AllCharacterStore.register(stranger_character)
		if picked == courted:
			_goto_bartender_after(_build_accepted_reaction(picked, stranger_character))
		else:
			_goto_bartender_after(_build_change_but_accept_reaction(picked, stranger_character))
	else:
		_goto_bartender_after(_build_rejected_reaction(picked, stranger_character))


## picked == courted 這一支的成親收尾:被搭訕的本人親自接受。
func _build_accepted_reaction(picked: Character, stranger_character: Character) -> Dialogue:
	var picked_speaker := DialogueSpeaker.new(picked.id, picked.full_name, picked.face_path, GameEnums.DialogueSide.LEFT)
	var stranger_speaker := DialogueSpeaker.new(stranger_character.id, stranger_character.full_name, stranger_character.face_path, GameEnums.DialogueSide.RIGHT)
	var lines: Array[DialogueLine] = [
		DialogueLine.new(picked_speaker.id, "這是我的榮幸。"),
		DialogueLine.new(stranger_speaker.id, "❤"),
	]
	return Dialogue.new([picked_speaker, stranger_speaker], lines, BACKGROUND_PATH)



## 玩家選了不是 courted 的人反告白,20% 成功率骰中的收尾:courted 出面引薦 picked,
## stranger 也接受了這位替補人選(見 _resolve_acceptance())。
func _build_change_but_accept_reaction(picked: Character, stranger_character: Character) -> Dialogue:
	var courted_speaker := DialogueSpeaker.new(courted.id, courted.full_name, courted.face_path, GameEnums.DialogueSide.LEFT)
	var picked_speaker := DialogueSpeaker.new(picked.id, picked.full_name, picked.face_path, GameEnums.DialogueSide.LEFT)
	var stranger_speaker := DialogueSpeaker.new(stranger_character.id, stranger_character.full_name, stranger_character.face_path, GameEnums.DialogueSide.RIGHT)
	var lines: Array[DialogueLine] = [
		DialogueLine.new(courted_speaker.id, "不太適合,但我有個適合的人選介紹給你,"),
		DialogueLine.new(picked_speaker.id, "你好...請問我有這個榮幸請你喝一杯嗎?"),
		DialogueLine.new(stranger_speaker.id, "好啊!❤"),
	]
	return Dialogue.new([courted_speaker, picked_speaker, stranger_speaker], lines, BACKGROUND_PATH)


## 玩家選了不是 courted 的人反告白,20% 成功率沒骰中的收尾:stranger 婉拒這位
## 替補人選,真的告白失敗,不寫入 mate(見 _resolve_acceptance())。
func _build_rejected_reaction(picked: Character, stranger_character: Character) -> Dialogue:
	var courted_speaker := DialogueSpeaker.new(courted.id, courted.full_name, courted.face_path, GameEnums.DialogueSide.LEFT)
	var picked_speaker := DialogueSpeaker.new(picked.id, picked.full_name, picked.face_path, GameEnums.DialogueSide.LEFT)
	var stranger_speaker := DialogueSpeaker.new(stranger_character.id, stranger_character.full_name, stranger_character.face_path, GameEnums.DialogueSide.RIGHT)
	var lines: Array[DialogueLine] = [
		DialogueLine.new(courted_speaker.id, "不太適合,但我有個適合的人選介紹給你,"),
		DialogueLine.new(picked_speaker.id, "你好...請問我有這個榮幸請你喝一杯嗎?"),
		DialogueLine.new(stranger_speaker.id, "這...恐怕有點不合適。"),
	]
	return Dialogue.new([courted_speaker, picked_speaker, stranger_speaker], lines, BACKGROUND_PATH)


func _build_declined_reaction(self_character: Character) -> Dialogue:
	var speaker := DialogueSpeaker.new(self_character.id, self_character.full_name, self_character.face_path, GameEnums.DialogueSide.LEFT)
	var lines: Array[DialogueLine] = [
		DialogueLine.new(speaker.id, "這恐怕有點不合適..."),
	]
	return Dialogue.new([speaker], lines, BACKGROUND_PATH)


## 搭訕流程的收尾一律接到這裡:把酒館老闆這位新講者跟他的招呼詞直接接在傳入的
## dialogue 後面播,不切場景(dialogue.speakers/lines 只是普通 Array,直接 append
## 即可)。招呼詞是整段對話的最後一句,不帶選項——播完(玩家點過去)由
## goto_dialogue() 的 on_finished 直接接手開 ActionPanel,next_scene_path 留空讓對話
## 畫面留在背景(不轉場),見 System/event/location_event.gd 的 on_finished 說明。
##
## 沒遇到搭訕(90% 機率)時呼叫端直接傳一個空 Dialogue(Dialogue.new([], [],
## BACKGROUND_PATH)),等同於單獨播一句酒館老闆招呼詞。
func _goto_bartender_after(dialogue: Dialogue) -> void:
	var bartender_speaker := DialogueSpeaker.new(BARTENDER_ID, BARTENDER_NAME, _bartender_face_path, GameEnums.DialogueSide.RIGHT)
	dialogue.speakers.append(bartender_speaker)
	dialogue.lines.append(DialogueLine.new(bartender_speaker.id, BARTENDER_GREETING))
	goto_dialogue(dialogue, "", func(): _open_recruit_panel())


## 酒館老闆招呼詞播完自動呼叫:隨機生 RECRUIT_HERO_COUNT 位英雄,彈出 ActionPanel 列出
## 來給玩家選。招募不關面板(_on_recruit_hero_selected() 只註冊角色,不呼叫
## ActionPanel.close()),那一列的按鈕靠 ActionPanelItem.disable_after_select 自己變灰,
## 玩家可以在同一次彈窗裡連續招募清單裡好幾位;按 × 才會呼叫 _return_to_map_location(),
## 回到觸發這個事件時記下的地點選單場景——ActionPanel 本身不知道也不需要知道關閉之後
## 該去哪,由這裡傳的 on_close callback 決定。
func _open_recruit_panel() -> void:
	var items: Array[ActionPanelItem] = []
	for i in range(RECRUIT_HERO_COUNT):
		items.append(_build_recruit_item(CharacterController.get_random_character(GameEnums.RankType.F)))
	ActionPanel.open(RECRUIT_PANEL_TITLE, items, func(): _return_to_map_location())


func _build_recruit_item(hero: Character) -> ActionPanelItem:
	var subtitle := "%d 歲" % [hero.age]
	return ActionPanelItem.new(hero.full_name, RECRUIT_BUTTON_LABEL, func(): _on_recruit_hero_selected(hero), hero.face_path, subtitle, true)


## 招募比照 Scenes/PartyEdit/party_edit.gd 的 _on_add_character_pressed() 寫法:
## AllCharacterStore.register() + CharacterRosterStore.all_characteres.append()。不呼叫
## ActionPanel.close()——面板留著讓玩家繼續招募其他人,這一列的按鈕會被 ActionPanel
## 自己 disabled(見 ActionPanelItem.disable_after_select),不需要在這裡另外處理。
func _on_recruit_hero_selected(hero: Character) -> void:
	AllCharacterStore.register(hero)
	CharacterRosterStore.all_characteres.append(hero)


func _return_to_map_location() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var error := tree.change_scene_to_file(_return_scene_path)
	if error != OK:
		printerr("Error changing scene from TownTavernEvent ActionPanel: ", error)
