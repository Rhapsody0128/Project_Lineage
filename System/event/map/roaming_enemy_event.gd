class_name RoamingEnemyEvent
extends LocationEvent

## 大地圖走近遊蕩敵人(RoamingEnemy)觸發的「先跳對話,再選擇要不要開戰」流程,比照
## System/event/castle/castle_gate_event.gd 的 CastleGateEvent,但精簡掉城門守衛「已經
## 站在門口」的判斷與 NavigationStore.push_return_scene_path()——這裡本來就是在
## Scenes/Map/map.tscn 上直接觸發,對話/戰鬥打完也是回到同一個 map.tscn,不需要額外記錄
## 「上一頁」。呼叫端(map.gd 偵測到玩家走近敵人時)只呼叫一次
## RoamingEnemyEvent.trigger(enemy)。敵人要不要從地圖上移除,只看戰鬥有沒有真的打贏:
## SELF_WIN 才呼叫 RoamingEnemySpawner.remove_enemy() 消耗掉;選「離開」、或開打了但戰敗/
## 平手,敵人都不會消失,一律呼叫 decline_encounter() 留著敵人只是暫時擋掉重複觸發
## (見 RoamingEnemySpawner 的 DECLINED_CLEAR_RADIUS 註解)——盜賊搶完戰利品後應該還在
## 原地,不是打完就憑空消失。

const RETURN_SCENE_PATH := "res://Scenes/Map/map.tscn"

var _enemy: RoamingEnemy


func _init(p_enemy: RoamingEnemy) -> void:
	_enemy = p_enemy


static func trigger(enemy: RoamingEnemy) -> void:
	var event := RoamingEnemyEvent.new(enemy)
	event._start()


func _start() -> void:
	var self_party := PartyStore.party
	var dialogue := _build_challenge(self_party, func():
		AskBattle.ask(
			self_party, _enemy.party,
			"res://Scenes/Battle/battle.tscn", RETURN_SCENE_PATH,
			"", _on_battle_result
		)
	)
	goto_dialogue(dialogue, RETURN_SCENE_PATH)


## 只有真的打贏才把敵人從地圖上消耗掉;戰敗或平手都算沒能擊退盜賊,敵人留在原地——
## 跟選「離開」共用同一套 decline_encounter() 暫時擋重觸發機制,避免播完結果對話回到
## map.tscn 時玩家還站在原地,立刻又撞上同一隻敵人重播一次。
func _on_battle_result(result: GameEnums.BattleResultType) -> void:
	if result == GameEnums.BattleResultType.SELF_WIN:
		RoamingEnemyStore.spawner.remove_enemy(_enemy)
	else:
		RoamingEnemyStore.spawner.decline_encounter(_enemy)
	goto_dialogue(_build_result(result), RETURN_SCENE_PATH)


## self_party 可能是 null(玩家還沒去 PartyEdit 按過「完成編輯」)——這種情況不生一支假的
## 隨機小隊頂替,直接不給「戰鬥」選項,只能「離開」,比照 CastleGateEvent._build_challenge。
func _build_challenge(self_party: Party, on_challenge_accepted: Callable) -> Dialogue:
	var has_party := self_party != null
	var player := self_party.leader if has_party else CharacterController.get_random_character()
	var bandit := _enemy.party.leader

	var player_speaker := DialogueSpeaker.new(player.id, player.full_name, player.face_path, GameEnums.DialogueSide.LEFT)
	var bandit_speaker := DialogueSpeaker.new(bandit.id, bandit.full_name, bandit.face_path, GameEnums.DialogueSide.RIGHT)

	# 選「離開」不消耗敵人,只是暫時擋掉重複觸發,讓玩家可以晚點回頭再打——跟打輸/
	# 平手同一套機制,見 _on_battle_result()。敵人只有在真的打贏時才會被 remove_enemy()。
	var on_declined := func(): RoamingEnemyStore.spawner.decline_encounter(_enemy)

	var lines: Array[DialogueLine] = []

	if has_party:
		var choices: Array[DialogueChoice] = [
			DialogueChoice.new("戰鬥", "", on_challenge_accepted),
			DialogueChoice.new("離開", RETURN_SCENE_PATH, on_declined),
		]
		lines = [
			DialogueLine.new(bandit_speaker.id, "一群盜賊擋住了去路！"),
			DialogueLine.new(player_speaker.id, "", choices),
		]
	else:
		var choices: Array[DialogueChoice] = [
			DialogueChoice.new("離開", RETURN_SCENE_PATH, on_declined),
		]
		lines = [
			DialogueLine.new(bandit_speaker.id, "一群盜賊擋住了去路！"),
			DialogueLine.new(player_speaker.id, "（我還沒整頓好隊伍,先撤退吧。）", choices),
		]

	return Dialogue.new([bandit_speaker, player_speaker], lines)


## 單句台詞沒有選項,播完由 goto_dialogue() 傳的 RETURN_SCENE_PATH 自動接手轉場。
## DRAW(平手)沒有另外的台詞,一律當作沒能擊退盜賊,跟戰敗共用同一句,比照 CastleGateEvent。
func _build_result(result: GameEnums.BattleResultType) -> Dialogue:
	var bandit_speaker := DialogueSpeaker.new(_enemy.party.leader.id, _enemy.party.leader.full_name, _enemy.party.leader.face_path, GameEnums.DialogueSide.RIGHT)
	var won := result == GameEnums.BattleResultType.SELF_WIN
	var lines: Array[DialogueLine] = [
		DialogueLine.new(bandit_speaker.id, "可惡,撤退！" if won else "戰利品,通通留下！"),
	]
	return Dialogue.new([bandit_speaker], lines)
