class_name CastleSiegeEvent
extends LocationEvent

## 城堡「聊天」按鈕的整段事件(見 Scenes/MapLocation/map_location.gd 的
## _on_castle_chat_button_pressed()):未解放時是「擋門對話→連續三場戰鬥→依勝負反應」,
## 解放後改成管家報告本月產出,比照 System/event/town/town_gate_event.gd 的 TownGateEvent
## 由事件物件接管全部場景轉換,呼叫端只呼叫一次 trigger()。
##
## 三場戰鬥開口說話的固定是同一位「堡主」(_guard,trigger() 當下隨機挑一位、整個事件
## 過程只挑這一次),但每一場實際交手的敵方小隊個別重骰(見 _start_battle()),對應需求
## 「連續打三場對應等級的敵人」。中途戰敗或選離開不記錄進度,下次「聊天」重新從第一場
## 開始——不存 wave 進度,只有全部三場都贏才呼叫 CastleStore.conquer()。

const BACKGROUND_PATH := GameEnums.CASTLE_INTERIOR_BACKGROUND_PATH
const WAVE_COUNT := 3

var _map_object: MapObject
var _return_scene_path: String
var _guard_rank: int
var _guard: Character
var _wave_index: int = 0


func _init(p_map_object: MapObject, p_return_scene_path: String) -> void:
	_map_object = p_map_object
	_return_scene_path = p_return_scene_path


static func trigger(map_object: MapObject, return_scene_path: String) -> void:
	var event := CastleSiegeEvent.new(map_object, return_scene_path)
	event._start()


func _start() -> void:
	if CastleStore.is_conquered(_map_object.id):
		goto_dialogue(_build_steward_report(), _return_scene_path)
		return

	_guard_rank = CastleStore.rank_for(_map_object.id)
	_guard = PartyController.get_random_party(_guard_rank, _map_object.nation).leader
	_wave_index = 0

	# 這趟會先繞去 Dialogue 場景,不是直接切去 Battle,所以「回上一頁」不能靠
	# NavigationStore.go_to() 在切場景當下自動抓 current_scene——比照 TownGateEvent,先明講
	# 最終邏輯上的上一頁就是 _return_scene_path。
	NavigationStore.push_return_scene_path(_return_scene_path)
	goto_dialogue(_build_wave_intro(), _return_scene_path)


func _start_battle() -> void:
	var enemy_party := PartyController.get_random_party(_guard_rank, _map_object.nation)
	AskBattle.ask(
		PartyStore.party, enemy_party,
		"res://Scenes/Battle/battle.tscn", _return_scene_path,
		"", _on_battle_result
	)


## AskBattle 打完(不管是選「是」跳過戰鬥、還是選「否」走完即時戰鬥)呼叫這裡收尾:
## 沒贏就當這趟攻城失敗,回原場景、不記錄進度;三場都贏才真正呼叫 CastleStore.conquer()。
func _on_battle_result(result: GameEnums.BattleResultType) -> void:
	if result != GameEnums.BattleResultType.SELF_WIN:
		goto_dialogue(_build_defeat_dialogue(), _return_scene_path)
		return
	_wave_index += 1
	if _wave_index >= WAVE_COUNT:
		CastleStore.conquer(_map_object.id)
		goto_dialogue(_build_victory_dialogue(), _return_scene_path)
	else:
		goto_dialogue(_build_wave_intro(), _return_scene_path)


## self_party(PartyStore.party)可能是 null(玩家還沒去 PartyEdit 按過「完成編輯」)——
## 比照 TownGateEvent/RoamingEnemyEvent,不生一支假的隨機小隊頂替,直接不給挑戰選項,
## 只能離開。開口說話的玩家一律是 LeaderStore.get_leader()(整團領導人),不是
## self_party.leader(戰場隊長)。
func _build_wave_intro() -> Dialogue:
	var has_party := PartyStore.party != null
	var player := LeaderStore.get_leader()
	var player_speaker := DialogueSpeaker.new(player.id, player.full_name, player.face_path, GameEnums.DialogueSide.LEFT)
	var guard_speaker := DialogueSpeaker.new(_guard.id, _guard.full_name, _guard.face_path, GameEnums.DialogueSide.RIGHT)
	var narrator := DialogueSpeaker.new("narrator", "", "", GameEnums.DialogueSide.NARRATOR)

	var speakers: Array[DialogueSpeaker] = [guard_speaker, player_speaker]
	var lines: Array[DialogueLine] = []

	match _wave_index:
		0:
			lines.append(DialogueLine.new(guard_speaker.id, "臭小鬼,膽敢闖進我們的領地,你是有什麼打算?"))
			lines.append(DialogueLine.new(narrator.id, "你觀察對方,看起來是 %s 級的%s佔領了這座城堡。" % [GameEnums.rank_label(_guard_rank), _bandit_label()]))
			speakers.append(narrator)
		1:
			lines.append(DialogueLine.new(guard_speaker.id, "滿能打的嘛,接下來就看看你有沒有膽接我二把手的劍!"))
		_:
			lines.append(DialogueLine.new(guard_speaker.id, "還真是難纏……這是最後一戰,我要親自上了!"))

	if has_party:
		var choices: Array[DialogueChoice] = [
			DialogueChoice.new(_accept_line(), "", func(): _start_battle()),
			DialogueChoice.new(_decline_line(), _return_scene_path),
		]
		lines.append(DialogueLine.new(player_speaker.id, "", choices))
	else:
		var choices: Array[DialogueChoice] = [
			DialogueChoice.new("離開", _return_scene_path),
		]
		lines.append(DialogueLine.new(player_speaker.id, "（我還沒整頓好隊伍,先回去編隊吧。）", choices))

	return Dialogue.new(speakers, lines, BACKGROUND_PATH)


func _accept_line() -> String:
	match _wave_index:
		0: return "無恥的%s,我是來伸張正義的!" % _bandit_label()
		1: return "廢話少說,放馬過來!"
		_: return "這次也不會輸!"


func _decline_line() -> String:
	match _wave_index:
		0: return "抱歉,我只是路過,我這就走。"
		1: return "三十六計走為上策。"
		_: return "我還是先撤退好了……"


func _build_defeat_dialogue() -> Dialogue:
	var guard_speaker := DialogueSpeaker.new(_guard.id, _guard.full_name, _guard.face_path, GameEnums.DialogueSide.RIGHT)
	var lines: Array[DialogueLine] = [
		DialogueLine.new(guard_speaker.id, "哈哈,滾回去舔傷口吧!"),
	]
	return Dialogue.new([guard_speaker], lines, BACKGROUND_PATH)


func _build_victory_dialogue() -> Dialogue:
	var guard_speaker := DialogueSpeaker.new(_guard.id, _guard.full_name, _guard.face_path, GameEnums.DialogueSide.RIGHT)
	var narrator := DialogueSpeaker.new("narrator", "", "", GameEnums.DialogueSide.NARRATOR)
	var lines: Array[DialogueLine] = [
		DialogueLine.new(guard_speaker.id, "不……這座城堡……我不甘心啊!"),
		DialogueLine.new(narrator.id, "%s首領倉皇逃走,你成功佔領了%s。" % [_bandit_label(), _map_object.name]),
	]
	return Dialogue.new([guard_speaker, narrator], lines, BACKGROUND_PATH)


## 這座城堡所屬國家(_map_object.nation,靜態寫死,見 System/map/map_object.gd)換算成
## 地形對應的強盜稱呼(GameEnums.terrain_bandit_label()),跟遊蕩者(見
## System/event/map/roaming_enemy_event.gd 的 _bandit_label())共用同一份對照表。
func _bandit_label() -> String:
	return GameEnums.bandit_label_for_nation(_map_object.nation)


## 佔領後每次「聊天」都是同一段固定內容,產出量是確定性算式,不需要另存「上個月」快照,
## 見 CastleStore.monthly_yield_for()。
func _build_steward_report() -> Dialogue:
	var steward := DialogueSpeaker.new("steward", "管家", "", GameEnums.DialogueSide.RIGHT)
	var info := CastleStore.monthly_yield_for(_map_object.id)
	var text := "你好,隊長。本月份%s的產出是 %d %s。" % [
		_map_object.name, info.amount, GameEnums.resource_string_label(info.resource_type)
	]
	var lines: Array[DialogueLine] = [
		DialogueLine.new(steward.id, text),
	]
	return Dialogue.new([steward], lines, BACKGROUND_PATH)
