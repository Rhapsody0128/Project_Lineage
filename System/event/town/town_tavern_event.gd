class_name TownTavernEvent
extends LocationEvent

## 酒館事件,見 Scenes/MapLocation/map_location.gd「酒館」按鈕:進門後由 TavernStore
## 決定這個月是不是有異鄉人(stranger)搭訕——是否搭訕/搭訕誰整個月只骰一次(見
## TavernStore.should_show_encounter()),同一個月不管進出酒館幾次都是同一個結果,直到
## 走完告白流程才會被標記 resolved、之後這個月不會再重複觸發。骰中但角色池裡沒有任何
## 符合資格(見 MarriageRule.can_propose())的角色時,只播一句佔位反應句,不進告白畫面。
##
## 不管有沒有遇到搭訕(沒骰中/骰中但沒人符合資格/告白流程跑完任何一種結局),最後
## 都會接到酒館老闆(bartender,見 _goto_bartender_after())的招呼台詞。招呼詞是一句
## 帶三個選項的選擇題(DialogueLine.choices,見 System/dialogue/):「雇用傭兵」接原本的
## 招募清單(_open_recruit_panel());「詢問委託」彈出另一個 ActionPanel 列出討伐/交貨/
## 送信三種委託報價供玩家接(_open_quest_offer_panel(),見 System/quest/);「離開」才是
## 真正離開酒館,切回觸發事件時記下的地點選單場景(_return_to_map_location())。前兩者
## 都是疊加彈出 ActionPanel(Scenes/ActionPanel/action_panel.gd),不切場景——招募清單
## 那一列按鈕按下後改成 disabled(見 ActionPanelItem.disable_after_select),玩家可以在
## 同一次彈窗裡連續招募好幾位;按 × 關閉面板不會離開酒館,而是回到老闆招呼詞重新
## 三選一(_return_to_bartender()),委託報價面板同一套收尾,要離開酒館得在招呼詞裡
## 明確點「離開」。搭訕反應對話跟酒館老闆招呼詞合併成同一個 Dialogue 播放(見
## _goto_bartender_after()),不是切兩次場景。
##
## CharacterController.get_random_character() 目前只有男性姓名庫,一律指派 MALE
## (見該檔案註解,女性角色池尚未建立),所以「性別相反」條件實務上要等女性角色池
## 補上才會常態成立——這是既有限制,不是這個事件本身的問題。
##
## trigger() 現在多帶一個 nation(該城鎮所屬國家,見 map_location.gd 的
## _on_tavern_button_pressed()),餵給 TavernStore 的招募清單/特殊推薦/搭訕對象生成——
## 抽選基礎評級跟著該國好感度(NationFavorRank.rank_for_favor())走,不再固定 F 級,
## 好感度愈高能遇到的人才評級愈高,見 TavernStore 的 _resolve_base_rank()。
##
## 老闆招呼詞之後除了原本的招募清單,額外多一列「特殊推薦」(見 SPECIAL_RECRUIT_* 常數/
## _build_special_recruit_item()):花 TavernStore.SPECIAL_RECRUIT_COST_GOLD 金幣才能招募,
## 頭像用 ActionPanelItem.icon_blacked_out 塗黑不讓玩家看到長相,只露出名字/等級,評級是
## 城鎮基礎評級 +1(封頂 SSS,見 TavernStore._special_recruit_rank());基礎評級已經是 SSS
## 時沒有更高評級可探,按鈕直接 initial_disabled。
##
## 招募(一般清單/特殊推薦)確定成功、或告白流程確定結婚成功時,都會立刻跳出
## CharacterPanel.open_for_character() 讓玩家直接看到剛到手這位角色的完整資料——比照
## 「玩家剛拿到一個新角色,理應馬上能看清楚」的體驗,不用玩家自己再手動去角色列表點開。
##
## 玩家在告白面板(MarriageProposalPanel,見 Scenes/Marriage/marriage_proposal_panel.gd)
## 按下「接受」/「婉拒」後的結果,以及最終要不要寫入 Character.mate,都由這個事件的
## _on_proposal_result() 收尾決定,面板本身不寫任何角色資料。
##
## 「接受」後還有一輪成功率判定(見 MarriageRule.roll_acceptance()):玩家在告白面板
## 清單裡選的人正是 stranger 屬意的 courted 時 100% 成功。玩家也可以
## 改選別人上場反告白(= 不讓 stranger 屬意的 courted 出面接受),這種情況只有 20%
## 成功率,沒骰中就是真的告白失敗,不會再補救;若一開始就按「婉拒」則完全不骰,
## 直接播婉拒台詞收尾。

const MARRIAGE_PROPOSAL_PANEL_SCENE := preload("res://Scenes/Marriage/marriage_proposal_panel.tscn")
const MARRIAGE_PANEL_TITLE := "有人向你告白"
const BACKGROUND_PATH := "res://Images/Dialogue/Town/town_tavern.png"

const BARTENDER_ID := "tavern_bartender"
const BARTENDER_NAME := "酒館老闆"
const BARTENDER_GREETING := "你好,有甚麼需要的嗎?"
const HIRE_MERCENARY_CHOICE_LABEL := "雇用傭兵"
const ASK_COMMISSION_CHOICE_LABEL := "詢問委託"
const LEAVE_CHOICE_LABEL := "離開"

const RECRUIT_PANEL_TITLE := "酒館老闆介紹的旅人"
const RECRUIT_BUTTON_LABEL := "招募"
const RECRUITED_BUTTON_LABEL := "已招募"

const SPECIAL_RECRUIT_BUTTON_LABEL := "招募(300 金幣)"
const SPECIAL_RECRUIT_CANNOT_AFFORD_MESSAGE := "金幣不足,無法招募特殊推薦的旅人。"

## 「詢問委託」報價面板固定列出這三種委託各一張(見 System/quest/),QuestLibrary.create_offer()
## 依這座城鎮所屬國家的好感度骰出各自的難度——之後新增委託種類時在這裡加。
const QUEST_OFFER_TYPES: Array[int] = [
	GameEnums.QuestType.BANDIT_SUBJUGATION, GameEnums.QuestType.DELIVERY, GameEnums.QuestType.COURIER,
]
const QUEST_OFFER_PANEL_TITLE := "公會委託"
const QUEST_ACCEPT_BUTTON_LABEL := "接受"
const QUEST_ACCEPTED_BUTTON_LABEL := "已受理"

var stranger: Character
var courted: Character
var _return_scene_path: String
var _bartender_face_path: String
var _nation: int


static func trigger(return_scene_path: String, nation: int) -> void:
	var event := TownTavernEvent.new()
	event._start(return_scene_path, nation)


func _start(return_scene_path: String, nation: int) -> void:
	_return_scene_path = return_scene_path
	_nation = nation
	var bartender_gender = Util.get_random_from_array([GameEnums.Gender.MALE, GameEnums.Gender.FEMALE])
	_bartender_face_path = FaceController.get_random_face_path(bartender_gender)

	if not TavernStore.should_show_encounter(_nation):
		_goto_bartender_after(Dialogue.new([], [], BACKGROUND_PATH))
		return

	stranger = TavernStore.encounter_stranger
	courted = TavernStore.encounter_courted

	if courted == null:
		TavernStore.mark_encounter_resolved()
		_goto_bartender_after(_build_no_one_available())
		return

	# 搭訕台詞播完不轉場(next_scene_path 留空),對話畫面留在背景,on_finished 直接疊加
	# ActionPanel 開告白面板——跟下面 _goto_bartender_after() 開招募面板同一套模式。
	goto_dialogue(_build_approach(), "", func(): _open_marriage_panel())


## 疊加共用的 Scenes/ActionPanel/action_panel.gd(autoload)顯示告白面板
## (MarriageProposalPanel,見 Scenes/Marriage/marriage_proposal_panel.gd)——不切場景,蓋在
## 觸發事件當下的對話畫面上。面板內容自己不知道也不需要知道結果要接到哪裡,由這裡傳的
## on_result callback 決定。這裡的 lambda 捕捉 self,撐住這個 RefCounted 事件物件活到玩家
## 真正按下按鈕的那一刻(跟本檔案其餘 callback 用法同一套道理,見檔案開頭陷阱說明)。按 ×
## 視同婉拒/取消,接到 panel.decline。
func _open_marriage_panel() -> void:
	var panel := MARRIAGE_PROPOSAL_PANEL_SCENE.instantiate()
	# 沿用 ActionPanel.DEFAULT_MIN_SIZE(1500x750)——那只是「最小」尺寸,不是固定尺寸:
	# MarriageProposalPanel 內容比 750 矮就照最小高度長,留白墊在下面;內容比 750 高時
	# PanelContainer 本來就會照子節點需要的高度自動長高(見 action_panel.gd 開頭「內容
	# 溢出」說明),沒必要另外傳更小的高度硬擠,不然反而會小於設計最小高度,顯得畫面很短。
	ActionPanel.open_custom(MARRIAGE_PANEL_TITLE, panel, panel.decline)
	# setup() 簽名是 (target_character, self_character, ...):target 是對方(搭訕的人,
	# stranger),self 是我方(被搭訕、原本屬意要出面的人,courted)——順序跟兩個變數的
	# 命名容易搞混,注意不要傳反。
	panel.setup(stranger, courted, GameEnums.ProposalMode.INCOMING, func(accepted: bool, self_character: Character, target_character: Character) -> void:
		_on_proposal_result(accepted, self_character, target_character)
	)


## 單句台詞沒有選項,播完由 goto_dialogue() 的 on_finished 直接接手疊加告白面板(見
## _start()/_open_marriage_panel())。
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


## 告白面板按下「接受」/「婉拒」後呼叫:self_character 是玩家最終選的人(不一定是
## courted,見 marriage_proposal_panel.gd 的清單選人邏輯),target_character
## 固定是 stranger。婉拒完全不骰,直接播婉拒台詞;接受則交給 _resolve_acceptance()
## 判定成功率、寫入 mate、決定分支對話,兩種結果最後都接到 _goto_bartender_after()。
##
## 婉拒台詞開口的一律是 courted(被告白的人,自始被 stranger 搭訕的對象),不是
## self_character(玩家在清單裡當下選的人)——選了別人只是玩家瀏覽/預覽,沒有
## 真的接受求婚,開口回絕的人選不會因為玩家點了誰而改變。
func _on_proposal_result(accepted: bool, self_character: Character, target_character: Character) -> void:
	TavernStore.mark_encounter_resolved()
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
		var marriage_text := "%s 與 %s 結婚了。" % [picked.full_name, stranger_character.full_name]
		NewsController.post(marriage_text, GameEnums.NewsCategory.MAJOR)
		MessageBar.show_message(marriage_text)
		MoraleStore.record_event("角色結婚", MoraleStore.MARRIAGE_DELTA)
		var reaction := _build_accepted_reaction(picked, stranger_character) if picked == courted else _build_change_but_accept_reaction(picked, stranger_character)
		_play_marriage_reaction(reaction, stranger_character)
	else:
		_goto_bartender_after(_build_rejected_reaction(picked, stranger_character))


## 成親反應對話播完(玩家點過去)當下就跳出新配偶的 CharacterPanel,不是等接續的酒館
## 老闆招呼詞也播完才顯示——這裡先單獨播 reaction 這段對話(不跟酒館老闆的招呼詞合併成
## 同一次播放),播完立刻彈 CharacterPanel,再接著呼叫 _goto_bartender_after() 用空
## Dialogue 續播老闆招呼詞、走原本「播完接開招募面板」的路。
func _play_marriage_reaction(reaction: Dialogue, stranger_character: Character) -> void:
	goto_dialogue(reaction, "", func() -> void:
		CharacterPanel.open_for_character(stranger_character)
		_goto_bartender_after(Dialogue.new([], [], BACKGROUND_PATH))
	)


## picked == courted 這一支的成親收尾:被搭訕的本人親自接受。
func _build_accepted_reaction(picked: Character, stranger_character: Character) -> Dialogue:
	var picked_speaker := DialogueSpeaker.new(picked.id, picked.full_name, picked.face_path, GameEnums.DialogueSide.LEFT)
	var stranger_speaker := DialogueSpeaker.new(stranger_character.id, stranger_character.full_name, stranger_character.face_path, GameEnums.DialogueSide.RIGHT)
	var lines: Array[DialogueLine] = [
		DialogueLine.new(picked_speaker.id, "這是我的榮幸。"),
		# DialogueLine.new(stranger_speaker.id, ""),
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
		DialogueLine.new(stranger_speaker.id, "好啊!"),
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
## 即可)。招呼詞是整段對話的最後一句,帶「雇用傭兵」/「詢問委託」/「離開」三個選項
## (DialogueLine.choices)——前兩個由 DialogueChoice.on_selected 直接開對應的
## ActionPanel,next_scene_path 留空讓對話畫面留在背景(不轉場)當 ActionPanel 的底圖;
## 「離開」才是真正離開酒館、切回地點選單場景(_return_to_map_location())。招募/委託
## 面板按 × 關閉時不會直接離開酒館,而是回到這裡重播一次老闆招呼詞(見
## _return_to_bartender()),讓玩家可以連續逛「雇用傭兵」「詢問委託」,要離開酒館得
## 明確點「離開」。
##
## 沒遇到搭訕(90% 機率)時呼叫端直接傳一個空 Dialogue(Dialogue.new([], [],
## BACKGROUND_PATH)),等同於單獨播一句酒館老闆招呼詞。
func _goto_bartender_after(dialogue: Dialogue) -> void:
	var bartender_speaker := DialogueSpeaker.new(BARTENDER_ID, BARTENDER_NAME, _bartender_face_path, GameEnums.DialogueSide.RIGHT)
	dialogue.speakers.append(bartender_speaker)
	var choices: Array[DialogueChoice] = [
		DialogueChoice.new(HIRE_MERCENARY_CHOICE_LABEL, "", func(): _open_recruit_panel()),
		DialogueChoice.new(ASK_COMMISSION_CHOICE_LABEL, "", func(): _open_quest_offer_panel()),
		DialogueChoice.new(LEAVE_CHOICE_LABEL, "", func(): _return_to_map_location()),
	]
	dialogue.lines.append(DialogueLine.new(bartender_speaker.id, BARTENDER_GREETING, choices))
	goto_dialogue(dialogue, "")


## 招募/委託面板按 × 關閉時呼叫:不離開酒館,重播一次老闆招呼詞(空 Dialogue,等同
## _start() 沒遇到搭訕那一支的播法),讓玩家回到「雇用傭兵/詢問委託/離開」三選一,
## 可以連續逛好幾種互動,不會逛完一種就被硬送回地點選單。
func _return_to_bartender() -> void:
	_goto_bartender_after(Dialogue.new([], [], BACKGROUND_PATH))


## 酒館老闆招呼詞選「雇用傭兵」時呼叫:彈出 ActionPanel 列出 TavernStore 目前這批候補
## 英雄供玩家選。清單是整個遊戲共用的同一份(見 TavernStore),同一個月內不管進出酒館
## 幾次都看到同一批人,只有跨月才會整批換新——不再每次開面板都重骰。招募不關面板
## (_on_recruit_hero_selected() 只註冊角色,不呼叫 ActionPanel.close()),那一列的按鈕靠
## ActionPanelItem.disable_after_select 自己變灰,玩家可以在同一次彈窗裡連續招募清單裡
## 好幾位;按 × 才會呼叫 _return_to_bartender(),回到老闆招呼詞重新三選一(不是直接離開
## 酒館)——ActionPanel 本身不知道也不需要知道關閉之後該去哪,由這裡傳的 on_close
## callback 決定。
func _open_recruit_panel() -> void:
	var items: Array[ActionPanelItem] = []
	items.append(_build_special_recruit_item())
	for hero in TavernStore.get_recruits(_nation):
		items.append(_build_recruit_item(hero))
	ActionPanel.open(RECRUIT_PANEL_TITLE, items, func(): _return_to_bartender())


## already_recruited:這位候補英雄是不是已經在玩家角色列裡——TavernStore 的清單同一個
## 月內重複進出酒館都是同一批人,上次已經招募過的要開面板就顯示成 disabled 的「已招募」,
## 不能讓玩家看起來還能再按一次(即使真的按了 try_add() 也只是無害地回傳 true,不會重複
## 入隊,但 UI 不該讓玩家以為那是一個有效動作)。
func _build_recruit_item(hero: Character) -> ActionPanelItem:
	var subtitle := "%d 歲" % hero.age
	var already_recruited := CharacterRosterStore.all_characteres.has(hero)
	var label := RECRUITED_BUTTON_LABEL if already_recruited else RECRUIT_BUTTON_LABEL
	var item := ActionPanelItem.new(hero.full_name, label, func() -> bool: return _on_recruit_hero_selected(hero), hero.face_path, subtitle, true, already_recruited)
	item.disabled_label = RECRUITED_BUTTON_LABEL
	return item


## 招募改叫共用入口 CharacterRosterStore.try_add()(跟 PartyEdit「新增角色」、小孩
## 成年共用同一份「是否已滿」判斷跟提示,見該檔案註解)——角色列已滿時 try_add()
## 自己會跳 MessageBar 提示玩家去角色列表解雇,不在這裡另外處理。回傳值直接轉給
## ActionPanelItem.disable_after_select:只有真的招募成功才把這一列的按鈕變
## disabled,滿了的話按鈕維持可按,玩家騰出空位後可以直接再按一次,不用關掉面板重開。
## 招募成功額外跳出 CharacterPanel,讓玩家立刻看清楚剛到手這位角色的完整資料。
func _on_recruit_hero_selected(hero: Character) -> bool:
	var added := CharacterRosterStore.try_add(hero)
	if added:
		CharacterPanel.open_for_character(hero)
	return added


## 特殊推薦這一列跟一般候補英雄清單同一套 already_recruited/disable 慣例,多兩個限制:
## _nation 好感度已經是最高評級時不再有更高的評級可探(TavernStore.special_recruit_available()
## 判斷),按鈕直接 initial_disabled;icon_blacked_out 讓頭像整張塗黑,不讓玩家招募前看到
## 長相,只露出名字/等級(subtitle 刻意不放年齡,呼應「只繡名字和等級」)。
func _build_special_recruit_item() -> ActionPanelItem:
	var hero := TavernStore.get_special_recruit(_nation)
	var  subtitle := "%d 歲" % hero.age
	var already_recruited := CharacterRosterStore.all_characteres.has(hero)
	var available := TavernStore.special_recruit_available(_nation)
	var label := RECRUITED_BUTTON_LABEL if already_recruited else SPECIAL_RECRUIT_BUTTON_LABEL
	var item := ActionPanelItem.new(hero.full_name, label, func() -> bool: return _on_special_recruit_selected(hero), hero.face_path, subtitle, true, already_recruited or not available, true)
	item.disabled_label = RECRUITED_BUTTON_LABEL
	return item


## 花錢招募:先確認付得起(付不起跳訊息、不消耗任何動作),再走跟一般招募同一套
## try_add() 流程——只有 try_add() 真的成功(角色列沒滿)才真的扣錢,角色列滿的話
## try_add() 自己會跳提示,這裡不額外扣錢,讓玩家騰出空位後可以直接再按一次。
func _on_special_recruit_selected(hero: Character) -> bool:
	var cost := {GameEnums.ResourceType.GOLD: TavernStore.SPECIAL_RECRUIT_COST_GOLD}
	if not BaseResourceStore.can_afford(cost):
		MessageBar.show_message(SPECIAL_RECRUIT_CANNOT_AFFORD_MESSAGE)
		return false
	var added := CharacterRosterStore.try_add(hero)
	if added:
		BaseResourceStore.spend(cost)
		CharacterPanel.open_for_character(hero)
	return added


## 「詢問委託」選項按下後呼叫:列出 QUEST_OFFER_TYPES 三種委託各一張報價,見
## System/quest/quest_library.gd 的 create_offer()——報價不快取,每次開面板都重新抽一輪
## (跟 TavernStore 招募清單每月固定不同,委託本來就該常換常新),該國已經有進行中的
## 同種委託時那一列改顯示成已受理、不能再接第二張(見 QuestStore.has_active_quest()),
## 按鈕靠 initial_disabled 而不是重新整份清單重蓋。按 × 回到老闆招呼詞重新三選一,跟
## _open_recruit_panel() 同一套 _return_to_bartender() 收尾。
func _open_quest_offer_panel() -> void:
	var items: Array[ActionPanelItem] = []
	for quest_type in QUEST_OFFER_TYPES:
		items.append(_build_quest_offer_item(quest_type))
	ActionPanel.open(QUEST_OFFER_PANEL_TITLE, items, func(): _return_to_bartender())


## 委託名稱|說明|難度(RANK)|類型|期限|接受——ActionPanelItem 只有 title/subtitle 兩塊
## 文字區,說明/難度/類型/期限合併塞進 subtitle,委託名稱當 title,接受/已受理當按鈕。
func _build_quest_offer_item(quest_type: int) -> ActionPanelItem:
	var offer := QuestLibrary.create_offer(quest_type, _nation)
	var already_active := QuestStore.has_active_quest(_nation, quest_type)
	var meta_line := "難度:%s ｜ 類型:%s ｜ 期限:%s" % [
		GameEnums.rank_label(offer.rank), GameEnums.quest_type_label(offer.quest_type), QuestLibrary.deadline_text_for(offer),
	]
	var subtitle := "%s\n%s" % [QuestLibrary.description_for(offer), meta_line]
	var label := QUEST_ACCEPTED_BUTTON_LABEL if already_active else QUEST_ACCEPT_BUTTON_LABEL
	var item := ActionPanelItem.new(QuestLibrary.title_for(offer), label, func() -> bool: return _on_quest_offer_selected(offer), "", subtitle, true, already_active)
	item.disabled_label = QUEST_ACCEPTED_BUTTON_LABEL
	return item


## disable_after_select 靠這裡的回傳值決定要不要真的變 disabled——按下當下再檢查一次
## has_active_quest() 是防呆(面板打開後、按下接受前理論上不會有其他管道插入同種委託,
## 但跟 _on_recruit_hero_selected() 同一套「回傳值反映是否真的成功」的慣例,不要假設
## 呼叫端狀態一定沒變)。
func _on_quest_offer_selected(offer: Quest) -> bool:
	if QuestStore.has_active_quest(offer.nation, offer.quest_type):
		return false
	QuestStore.accept_quest(offer)
	MessageBar.show_message("接下了委託:%s" % QuestLibrary.title_for(offer))
	return true


func _return_to_map_location() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var error := tree.change_scene_to_file(_return_scene_path)
	if error != OK:
		printerr("Error changing scene from TownTavernEvent ActionPanel: ", error)
