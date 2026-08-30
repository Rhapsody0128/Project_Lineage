class_name BaseMarriageEvent
extends LocationEvent

## 城鎮中心聯姻流程的 Dialogue 演出層,見 Scenes/Base/base_action_panel.gd 的
## _open_stronghold_marriage_panel():玩家在 StrongholdMarriagePanel 只選「聯姻角色」跟
## 「寄信國家」兩件事,一按「確認聯姻」就在 trigger() 當下立刻扣掉這次名額(不管後面選不
## 選候選人、選了會不會被接受,名額都算用掉了)。接下來分三段:
##
## 1. 整團領導人(LeaderStore.get_leader(),台詞裡的「大人」)問聯姻角色有沒有心儀的對象、
##    要不要幫忙寄信(proposer 是領導人本人時沒有「大人」可以問,改成領導人自己的獨白,見
##    _build_self_request_dialogue())。
## 2. 彈出候選人盲選清單(_open_candidate_picker(),Scenes/Marriage/marriage_candidate_list.gd
##    的 MarriageCandidateList 塞進共用的 Scenes/ActionPanel/action_panel.gd(autoload),
##    只顯示姓名/年齡——玩家角色本人根本沒見過這些候選人,不該一開始就看得到完整素質/血統/
##    家族,跟酒館告白流程「看得到完整情報」刻意不同)。玩家可以選一位候選人,也可以直接
##    婉拒(不選任何人,回一句「沒有心儀的對象」的獨白)。
## 3. 選了候選人的話,場景切到候選人那邊回覆是否接受(是否接受在選定候選人的當下就骰定,
##    背景依候選人血統決定是平民住宅還是王座廳);沒選人的話直接進 _finish() 收尾。
##
## goto_dialogue() 會真的切場景離開 base.tscn——觸發時呼叫端
## (_open_stronghold_marriage_panel())要先 ActionPanel.close(false) 把目前開著的城鎮中心
## 面板藏起來,不然它是掛在 ActionPanel 這個 autoload CanvasLayer 上,不會因為切場景被
## 收掉,會一直疊在 Dialogue 畫面最上層,所以這裡的候選人盲選清單能直接沿用同一個已經空出
## 來的 ActionPanel,不需要另開一層。選完/婉拒各自負責 ActionPanel.close(false)(見
## _on_candidate_picked()/_on_candidate_declined())。演出結束後改呼叫
## BaseBuildingEvent.open_action_panel() 開一份全新的面板顯示結果,不去嘗試復用切場景前
## 那份舊的 BaseBuildingPanelContent。

const THRONE_ROOM_NOBLE_THRESHOLD := 50.0
const CANDIDATE_PANEL_TITLE := "回信人選"

var _building: Building
var _proposer: Character
var _nation: int
var _candidate: Character = null
var _accepted: bool = false


## Scenes/Base/base_action_panel.gd 的 _open_stronghold_marriage_panel() 按下「確認聯姻」
## 後直接呼叫這裡啟動整段事件——名額在這裡立刻扣掉,不等候選人選完才扣(需求:「選定之後
## 等於消耗掉次數」)。
static func trigger(building: Building, proposer: Character, nation: int) -> void:
	MarriageQuotaStore.consume()
	var event := BaseMarriageEvent.new()
	event._building = building
	event._proposer = proposer
	event._nation = nation
	event._start()


func _start() -> void:
	goto_dialogue(_build_request_dialogue(), "", func(): _open_candidate_picker())


## 領導人問聯姻角色有沒有心儀的對象這段對話,前提是兩人不是同一個人——玩家選聯姻角色時
## 也可以選到領導人本人(StrongholdMarriagePanel 的清單沒有排除領導人),這種情況不會有
## 「大人」可以問,改成領導人自己的獨白(見 _build_self_request_dialogue())。
func _build_request_dialogue() -> Dialogue:
	var leader := LeaderStore.get_leader()
	if _proposer == leader:
		return _build_self_request_dialogue(leader)

	var leader_speaker := DialogueSpeaker.new(leader.id, leader.title_full_name, leader.face_path, GameEnums.DialogueSide.RIGHT)
	var proposer_speaker := DialogueSpeaker.new(_proposer.id, _proposer.title_full_name, _proposer.face_path, GameEnums.DialogueSide.LEFT)
	var nation_label := GameEnums.bloodline_nation_label(_nation)
	var lines: Array[DialogueLine] = [
		DialogueLine.new(leader_speaker.id, "%s,你年紀也差不多也該結婚了,我替你向%s國寫封信吧,你有心儀的對象嗎?" % [_proposer.title_full_name, nation_label]),
		DialogueLine.new(proposer_speaker.id, "這..."),
	]
	return Dialogue.new([leader_speaker, proposer_speaker], lines, GameEnums.base_building_background_path(_building.type))


func _build_self_request_dialogue(leader: Character) -> Dialogue:
	var leader_speaker := DialogueSpeaker.new(leader.id, leader.title_full_name, leader.face_path, GameEnums.DialogueSide.LEFT)
	var lines: Array[DialogueLine] = [
		DialogueLine.new(leader_speaker.id, "我曾有過一個心儀的對象...今天我決定寫信給他...."),
	]
	return Dialogue.new([leader_speaker], lines, GameEnums.base_building_background_path(_building.type))


## 候選人盲選:只顯示姓名/年齡,不用 CharacterSelectOverlay/CharacterDetailView 那套完整
## 情報選人畫面——MarriageCandidateList(Scenes/Marriage/marriage_candidate_list.gd)塞進
## 共用的 ActionPanel(autoload),疊在目前 Dialogue 畫面背景上,不切場景。此時 ActionPanel
## 已經在 _open_stronghold_marriage_panel() 那步被 close(false) 空出來,可以直接沿用。
## 沒有另外的「都沒有中意的人選」按鈕——ActionPanel 的 × 鈕(on_close)就是唯一的婉拒
## 入口,選了候選人走 candidate_picked,不選就是婉拒,兩條分支不會搶著跑。
func _open_candidate_picker() -> void:
	var candidates := MarriageCandidateGenerator.generate_candidates(_proposer, _nation)
	var list := MarriageCandidateList.new()
	ActionPanel.open_custom(CANDIDATE_PANEL_TITLE, list, func(): _on_candidate_declined())
	list.setup(candidates)
	list.candidate_picked.connect(_on_candidate_picked)


## 選了候選人:是否接受在這裡就骰定(_accepted),不是播到那句才骰——這樣接下來的 Dialogue
## 狀態是確定的,不會因為玩家中途做了其他操作而改變結果。ActionPanel.close(false) 是必要
## 的一步(trigger_callback=false,避免又觸發上面那個 declined 分支)——goto_dialogue()
## 接下來會真的切場景離開目前畫面,這層盲選清單自己也要先關掉,不然會一路疊在 Dialogue
## 畫面最上層。
func _on_candidate_picked(candidate: Character) -> void:
	_candidate = candidate
	_accepted = MarriageRule.roll_alliance_success()
	ActionPanel.close(false)
	goto_dialogue(_build_reaction_dialogue(), "", func(): _finish())


func _build_reaction_dialogue() -> Dialogue:
	# 候選人(對方)是聯姻對象,對話裡不顯示姓氏(見使用者需求),名牌只用 given name;
	# _proposer 是玩家自己的角色,正常顯示全名。
	var candidate_speaker := DialogueSpeaker.new(_candidate.id, _candidate.name, _candidate.face_path, GameEnums.DialogueSide.RIGHT)
	var text := (
		"我就知道%s選擇的對象會記得我!我要去追尋真愛了!" % _proposer.title_full_name if _accepted
		else "這誰？"
	)
	var lines: Array[DialogueLine] = [DialogueLine.new(candidate_speaker.id, text)]
	return Dialogue.new([candidate_speaker], lines, _candidate_background_path())


func _candidate_background_path() -> String:
	if _candidate.bloodline.get_total_noble_percentage() >= THRONE_ROOM_NOBLE_THRESHOLD:
		return GameEnums.TOWN_THRONE_ROOM_BACKGROUND_PATH
	return GameEnums.TOWN_RESIDENTIAL_BACKGROUND_PATH


## 沒選任何候選人:聯姻角色自己回絕領導人的好意,不進候選人反應那段對話,直接收尾。這裡是
## ActionPanel 的 on_close(× 鈕)handler——close(false) 避免 on_close 被觸發時自己又呼叫一次
## 形成無謂的重入。
func _on_candidate_declined() -> void:
	ActionPanel.close(false)
	goto_dialogue(_build_decline_dialogue(), "", func(): _finish())


func _build_decline_dialogue() -> Dialogue:
	var proposer_speaker := DialogueSpeaker.new(_proposer.id, _proposer.title_full_name, _proposer.face_path, GameEnums.DialogueSide.LEFT)
	var lines: Array[DialogueLine] = [
		DialogueLine.new(proposer_speaker.id, "感謝大人好意,目前沒有心儀的對象,也不打算成家。"),
	]
	return Dialogue.new([proposer_speaker], lines, GameEnums.base_building_background_path(_building.type))


func _finish() -> void:
	var nation_label := GameEnums.bloodline_nation_label(_nation)
	var result_text: String

	if _candidate == null:
		result_text = "%s 婉拒了這次聯姻安排,本年度名額已用掉一個。" % _proposer.title_full_name
	elif _accepted:
		_proposer.marry(_candidate)
		AllCharacterStore.register(_candidate)
		result_text = "%s 向%s國聯姻成功,與 %s 結婚了。" % [_proposer.title_full_name, nation_label, _candidate.title_full_name]
		NewsController.post(result_text, GameEnums.NewsCategory.MAJOR)
		MessageBar.show_message(result_text)
		MoraleStore.record_event("角色結婚", MoraleStore.MARRIAGE_DELTA)
	else:
		result_text = "%s 向%s國寄出的聯姻信被拒絕了。" % [_proposer.title_full_name, nation_label]

	BaseBuildingEvent.open_action_panel(_building, func(content: BaseBuildingPanelContent) -> void:
		content._marriage_result_text = result_text
	)
