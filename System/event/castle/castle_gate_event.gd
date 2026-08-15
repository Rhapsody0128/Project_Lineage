class_name CastleGateEvent
extends LocationEvent

## 城堡守衛「擋門 → 戰鬥 → 依勝負反應」整段事件,見 Scenes/MapLocation/map_location.gd
## 「城堡」按鈕:呼叫端只呼叫一次 CastleGateEvent.trigger(return_scene_path),接下來
## 對話怎麼串、什麼時候彈 AskBattle、戰鬥打完依勝負秀哪句台詞,全部交給這個事件物件
## 接管,Scenes 層不需要知道任何細節。擋門前跟打完戰鬥後講話的固定是同一位守衛
## (guard,trigger() 當下隨機挑一位、整個事件過程只挑這一次),不是兩個對不上臉的路人。

var guard: Hero
var _return_scene_path: String


func _init(p_return_scene_path: String = "") -> void:
	_return_scene_path = p_return_scene_path
	guard = HeroController.get_random_hero()


## 呼叫端(map_location.gd)按下「城堡」按鈕時呼叫這裡啟動整段事件。return_scene_path
## 是這個事件全程「回原地」的目的地——擋門對話選「離開」、或闖進去打完戰鬥依勝負秀完
## 台詞,最後都是回到這裡,不會停在事件中途繞去的 Dialogue/Battle 場景上。
static func trigger(return_scene_path: String) -> void:
	var event := CastleGateEvent.new(return_scene_path)
	event._start()


func _start() -> void:
	var self_party := PartyStore.party
	var guard_party := PartyController.get_random_party()

	# 這趟會先繞去 Dialogue 場景,不是直接切去 Battle,所以「回上一頁」不能靠
	# NavigationStore.go_to() 在切場景當下自動抓 current_scene(那樣抓到的會是
	# Dialogue 自己)——在這裡先明講最終邏輯上的上一頁就是 _return_scene_path。
	NavigationStore.push_return_scene_path(_return_scene_path)

	var dialogue := _build_challenge(self_party, func():
		AskBattle.ask(
			self_party, guard_party,
			"res://Scenes/Battle/battle.tscn", _return_scene_path,
			"", _on_battle_result
		)
	)
	goto_dialogue(dialogue, _return_scene_path)


## AskBattle 打完城堡守衛挑戰(不管是選「是」跳過戰鬥、還是選「否」走完即時戰鬥)呼叫
## 這裡收尾:依勝負繞去 Dialogue 場景秀同一位守衛的一句反應,播完回到 _return_scene_path。
func _on_battle_result(result: GameEnums.BattleResultType) -> void:
	var won := result == GameEnums.BattleResultType.SELF_WIN
	goto_dialogue(_build_result(won), _return_scene_path)


## 玩家選「闖進去」、選「離開」回原本場景——「闖進去」不直接切場景(next_scene_path
## 傳空字串),改由 on_challenge_accepted(_start() 傳入的那個彈 AskBattle 的 Callable)
## 接手,再依玩家選擇決定去哪個場景。
##
## self_party 可能是 null(玩家還沒去 PartyEdit 按過「完成編輯」,沒有真正屬於他的
## 隊伍)——這種情況不生一支假的隨機小隊頂替,直接不給「闖進去」選項,只能「離開」,
## 守衛台詞也換成請玩家先去整隊。
func _build_challenge(self_party: Party, on_challenge_accepted: Callable) -> Dialogue:
	var has_party := self_party != null
	var player := self_party.leader if has_party else HeroController.get_random_hero()

	var player_speaker := DialogueSpeaker.new(player.id, player.full_name, player.face_path, GameEnums.DialogueSide.LEFT)
	var guard_speaker := DialogueSpeaker.new(guard.id, guard.full_name, guard.face_path, GameEnums.DialogueSide.RIGHT)

	var lines: Array[DialogueLine] = []

	if has_party:
		var choices: Array[DialogueChoice] = [
			DialogueChoice.new("闖進去", "", on_challenge_accepted),
			DialogueChoice.new("離開", _return_scene_path),
		]
		lines = [
			DialogueLine.new(guard_speaker.id, "站住,沒有許可不准進入。"),
			DialogueLine.new(player_speaker.id, "", choices),
		]
	else:
		var choices: Array[DialogueChoice] = [
			DialogueChoice.new("離開", _return_scene_path),
		]
		lines = [
			DialogueLine.new(guard_speaker.id, "站住,沒有許可不准進入。"),
			DialogueLine.new(player_speaker.id, "（我還沒整頓好隊伍,先回去編隊吧。）", choices),
		]

	return Dialogue.new([guard_speaker, player_speaker], lines)


## 單句台詞沒有選項,播完由 goto_dialogue() 傳的 next_scene_path 自動接手轉場。
## DRAW(平手)沒有另外的台詞,一律當作沒能闖進去,跟戰敗共用同一句「不要再來了」。
func _build_result(won: bool) -> Dialogue:
	var guard_speaker := DialogueSpeaker.new(guard.id, guard.full_name, guard.face_path, GameEnums.DialogueSide.RIGHT)
	var lines: Array[DialogueLine] = [
		DialogueLine.new(guard_speaker.id, "國王不會饒過你的..." if won else "不要再來了"),
	]
	return Dialogue.new([guard_speaker], lines)
