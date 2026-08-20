class_name BaseBuildingEvent
extends LocationEvent

## 根據地點擊建築觸發,見 Scenes/Base/base.gd 的 _unhandled_input():播一句對應
## Building.type 的 Dialogue(Images/Dialogue/Base/Building/<BUILDING_TYPE>.png,見
## GameEnums.base_building_background_path()),播完(玩家看完最後一句,不需要再多點
## 一次選項)由 on_finished 直接接手彈出 ActionPanel——跟
## System/event/town/town_tavern_event.gd 的 _goto_bartender_after()/_open_recruit_panel()
## 同一套寫法:next_scene_path 留空讓對話畫面留在背景,不用真的切場景。彈出的是共用
## Scenes/ActionPanel/action_panel.gd(autoload)那個外殼,跟酒館招募清單同一張臉,
## 只是內容區塊換成 Scenes/Base/base_action_panel.gd(BaseBuildingPanelContent)——不
## 另開一個長相不同的專用面板。玩家按面板右上角 × 才呼叫 _return_to_base() 真正切回
## Scenes/Base/base.tscn。


const BASE_SCENE_PATH := "res://Scenes/Base/base.tscn"


static func trigger(building: Building) -> void:
	var event := BaseBuildingEvent.new()
	event._start(building)


func _start(building: Building) -> void:
	goto_dialogue(_build_intro(building), "", func(): _open_action_panel(building))


func _build_intro(building: Building) -> Dialogue:
	var narrator := DialogueSpeaker.new("narrator", "", "", GameEnums.DialogueSide.NARRATOR)
	var lines: Array[DialogueLine] = [
		DialogueLine.new(narrator.id, "你走進了%s。" % building.name),
	]
	return Dialogue.new([narrator], lines, GameEnums.base_building_background_path(building.type))


func _open_action_panel(building: Building) -> void:
	ActionPanel.open_custom(building.name, BaseBuildingPanelContent.new(building), func(): _return_to_base())


func _return_to_base() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var error := tree.change_scene_to_file(BASE_SCENE_PATH)
	if error != OK:
		printerr("Error changing scene from BaseBuildingEvent: ", error)
