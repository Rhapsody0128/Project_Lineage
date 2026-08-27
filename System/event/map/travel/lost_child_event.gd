class_name LostChildEvent
extends LocationEvent

## 旅行事件之一(見 System/event/map/travel/travel_event_library.gd):路上遇到一個
## 迷路的小孩,純粹的道德選擇——兩個選項都不動任何數值,只有不同的收尾台詞,用來驗證
## 「旅行事件不一定要有機制效果」這條路徑,之後同類型的風味事件直接照抄這支的結構就好。

const RETURN_SCENE_PATH := "res://Scenes/Map/map.tscn"


static func trigger(player_pos: Vector2) -> void:
	var event := LostChildEvent.new()
	event._start(player_pos)


func _start(player_pos: Vector2) -> void:
	var dialogue := _build_prompt(player_pos)
	goto_dialogue(dialogue, RETURN_SCENE_PATH)


func _build_prompt(player_pos: Vector2) -> Dialogue:
	var player := LeaderStore.get_leader()
	var narrator := DialogueSpeaker.new("narrator", "", "", GameEnums.DialogueSide.NARRATOR)
	var player_speaker := DialogueSpeaker.new(player.id, player.full_name, player.face_path, GameEnums.DialogueSide.LEFT)

	# 兩個選項都靠 lambda 捕捉 self(event 物件),不能直接傳裸方法參照——這是 RefCounted
	# 事件物件在 trigger() 返回後撐不住引用計數的既有陷阱,見 LocationEvent 檔頭註解。
	var choices: Array[DialogueChoice] = [
		DialogueChoice.new("帶他去附近城鎮", "", func(): _on_choice_selected(true)),
		DialogueChoice.new("沒空,繼續趕路", "", func(): _on_choice_selected(false)),
	]

	var lines: Array[DialogueLine] = [
		DialogueLine.new(narrator.id, "一個哭泣的小孩坐在路邊,似乎跟家人走散了。"),
		DialogueLine.new(player_speaker.id, "（要幫忙送他回城鎮嗎?）", choices),
	]
	return Dialogue.new([narrator, player_speaker], lines, _background_path(player_pos))


func _on_choice_selected(helped: bool) -> void:
	goto_dialogue(_build_result(helped), RETURN_SCENE_PATH)


func _build_result(helped: bool) -> Dialogue:
	var narrator := DialogueSpeaker.new("narrator", "", "", GameEnums.DialogueSide.NARRATOR)
	var text := "（你牽著小孩的手,一路送到最近的城鎮才放心離開。）" if helped \
		else "（你猶豫了一下,還是決定先趕路——希望他能自己找到家人。）"
	var lines: Array[DialogueLine] = [DialogueLine.new(narrator.id, text)]
	return Dialogue.new([narrator], lines)


## 背景圖沿用最近城鎮的地形對話背景,比照 RoamingEnemyEvent._background_path()。
func _background_path(player_pos: Vector2) -> String:
	var nation_type := MapNationLookup.nearest_town_nation(player_pos)
	var terrain_type := GameEnums.bloodline_nation_terrain(nation_type) if nation_type != -1 else GameEnums.TerrainType.PLAINS
	return GameEnums.terrain_background_path(terrain_type)
