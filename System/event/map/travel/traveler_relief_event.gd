class_name TravelerReliefEvent
extends LocationEvent

## 旅行事件之一(見 System/event/map/travel/travel_event_library.gd):路上遇到落難旅人
## 求助,資助他能換取當地國家好感度——驗證「花 GOLD 換好感度」這條路徑,國家判斷比照
## RoamingEnemyEvent,用觸發當下玩家座標找最近城鎮所屬國家(見 MapNationLookup)。數值都是
## 先擺著的預留值,之後要調平衡直接改這幾個常數。
const RETURN_SCENE_PATH := "res://Scenes/Map/map.tscn"

const RELIEF_COST := 50
const RELIEF_FAVOR_REWARD := 5


static func trigger(player_pos: Vector2) -> void:
	var event := TravelerReliefEvent.new()
	event._start(player_pos)


func _start(player_pos: Vector2) -> void:
	var nation_type := MapNationLookup.nearest_town_nation(player_pos)
	var dialogue := _build_prompt(player_pos, nation_type)
	goto_dialogue(dialogue, RETURN_SCENE_PATH)


## 身上的 GOLD 不夠資助時,只給「愛莫能助」一個選項,不讓玩家選了資助卻扣出負數存量。
func _build_prompt(player_pos: Vector2, nation_type: int) -> Dialogue:
	var narrator := DialogueSpeaker.new("narrator", "", "", GameEnums.DialogueSide.NARRATOR)
	var player := LeaderStore.get_leader()
	var player_speaker := DialogueSpeaker.new(player.id, player.full_name, player.face_path, GameEnums.DialogueSide.LEFT)

	var can_afford := BaseResourceStore.can_afford({GameEnums.ResourceType.GOLD: RELIEF_COST})
	var choices: Array[DialogueChoice] = []
	if can_afford:
		choices.append(DialogueChoice.new("資助 %d 金錢" % RELIEF_COST, "", func(): _on_choice_selected(player_pos, nation_type, true)))
	choices.append(DialogueChoice.new("愛莫能助", "", func(): _on_choice_selected(player_pos, nation_type, false)))

	var lines: Array[DialogueLine] = [
		DialogueLine.new(narrator.id, "一名衣衫襤褸的旅人攔住去路,說盤纏被劫、走投無路。"),
		DialogueLine.new(player_speaker.id, "（要資助他嗎?）", choices),
	]
	return Dialogue.new([narrator, player_speaker], lines, _background_path(nation_type))


func _on_choice_selected(player_pos: Vector2, nation_type: int, helped: bool) -> void:
	goto_dialogue(_build_result(nation_type, helped), RETURN_SCENE_PATH)


## nation_type 為 -1(理論上不會發生,見 MapNationLookup 註解)時退回純粹的感謝詞,不發
## 好感度——沒有城鎮可歸屬,自然沒有國家能記你這份人情。
func _build_result(nation_type: int, helped: bool) -> Dialogue:
	var narrator := DialogueSpeaker.new("narrator", "", "", GameEnums.DialogueSide.NARRATOR)
	var text: String

	if not helped:
		text = "（你婉拒了他的請求,旅人失望地繼續往前走。）"
	else:
		BaseResourceStore.spend({GameEnums.ResourceType.GOLD: RELIEF_COST})
		if nation_type == -1:
			text = "（旅人千恩萬謝地收下了盤纏。）"
		else:
			NationFavorStore.add_favor(nation_type, RELIEF_FAVOR_REWARD)
			var nation_label := GameEnums.bloodline_nation_label(nation_type)
			text = "（旅人千恩萬謝地收下了盤纏,說會告訴鄉親你的義舉——%s 對你的好感度 +%d。）" % [nation_label, RELIEF_FAVOR_REWARD]

	var lines: Array[DialogueLine] = [DialogueLine.new(narrator.id, text)]
	return Dialogue.new([narrator], lines)


## 背景圖沿用最近城鎮的地形對話背景,比照 RoamingEnemyEvent._background_path()。
func _background_path(nation_type: int) -> String:
	var terrain_type := GameEnums.bloodline_nation_terrain(nation_type) if nation_type != -1 else GameEnums.TerrainType.PLAINS
	return GameEnums.terrain_background_path(terrain_type)
