class_name WildAnimalAttackEvent
extends LocationEvent

## 旅行事件之一(見 System/event/map/travel/travel_event_library.gd):路上遇到野獸,不是
## RoamingEnemy 那種正式小隊戰鬥,不切去 Battle 場景——「迎戰」/「繞道」的結果直接用數值
## 表示(HP 損傷、GOLD 戰利品),比照風險交換型的旅行事件範本。數值都是先擺著的預留值,
## 之後要調平衡直接改這幾個常數。
const RETURN_SCENE_PATH := "res://Scenes/Map/map.tscn"

const FIGHT_DAMAGE := 15
const FIGHT_GOLD_REWARD := 30


static func trigger(player_pos: Vector2) -> void:
	var event := WildAnimalAttackEvent.new()
	event._start(player_pos)


## 沒有編隊(self_party 為 null,玩家還沒去 PartyEdit 按過「完成編輯」)時沒有角色可以
## 承受傷害,比照 RoamingEnemyEvent 的做法,直接只給「繞道」一個選項。
func _start(player_pos: Vector2) -> void:
	var self_party := PartyStore.party
	var dialogue := _build_prompt(player_pos, self_party)
	goto_dialogue(dialogue, RETURN_SCENE_PATH)


func _build_prompt(player_pos: Vector2, self_party: Party) -> Dialogue:
	var narrator := DialogueSpeaker.new("narrator", "", "", GameEnums.DialogueSide.NARRATOR)
	var player := LeaderStore.get_leader()
	var player_speaker := DialogueSpeaker.new(player.id, player.title_full_name, player.face_path, GameEnums.DialogueSide.LEFT)

	var has_party := self_party != null and not self_party.characteres.is_empty()
	var lines: Array[DialogueLine] = []

	if has_party:
		var choices: Array[DialogueChoice] = [
			DialogueChoice.new("迎戰", "", func(): _on_choice_selected(player_pos, self_party, true)),
			DialogueChoice.new("繞道避開", "", func(): _on_choice_selected(player_pos, self_party, false)),
		]
		lines = [
			DialogueLine.new(narrator.id, "草叢傳來低吼聲——一群野獸擋住了去路！"),
			DialogueLine.new(player_speaker.id, "（要迎戰嗎?打贏能拿到一些戰利品,但可能會有人受傷。）", choices),
		]
	else:
		lines = [
			DialogueLine.new(narrator.id, "草叢傳來低吼聲——一群野獸擋住了去路！"),
			DialogueLine.new(player_speaker.id, "（我還沒整頓好隊伍,先繞道避開吧。）"),
		]

	return Dialogue.new([narrator, player_speaker], lines, _background_path(player_pos))


func _on_choice_selected(player_pos: Vector2, self_party: Party, fight: bool) -> void:
	goto_dialogue(_build_result(player_pos, self_party, fight), RETURN_SCENE_PATH)


func _build_result(player_pos: Vector2, self_party: Party, fight: bool) -> Dialogue:
	var narrator := DialogueSpeaker.new("narrator", "", "", GameEnums.DialogueSide.NARRATOR)
	var lines: Array[DialogueLine] = []

	if fight:
		var target: Character = Util.get_random_from_array(self_party.characteres)
		target.take_damage(FIGHT_DAMAGE)
		BaseResourceStore.add(GameEnums.ResourceType.GOLD, FIGHT_GOLD_REWARD)
		lines = [DialogueLine.new(narrator.id, "（擊退了野獸,%s 受了點輕傷,搜刮到 %d 金錢。）" % [target.title_full_name, FIGHT_GOLD_REWARD])]
	else:
		lines = [DialogueLine.new(narrator.id, "（繞了條遠路,平安避開了野獸。）")]

	return Dialogue.new([narrator], lines, _background_path(player_pos))


## 背景圖沿用最近城鎮的地形對話背景,比照 RoamingEnemyEvent._background_path()。
func _background_path(player_pos: Vector2) -> String:
	var nation_type := MapNationLookup.nearest_town_nation(player_pos)
	var terrain_type := GameEnums.bloodline_nation_terrain(nation_type) if nation_type != -1 else GameEnums.TerrainType.PLAINS
	return GameEnums.terrain_background_path(terrain_type)
