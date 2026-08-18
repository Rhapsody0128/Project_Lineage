class_name BaseBuildingEvent
extends LocationEvent

## 根據地點擊建築觸發,見 Scenes/Base/base.gd 的 _unhandled_input():播一句對應
## Building.type 的 Dialogue(Images/Dialogue/Base/Building/<BUILDING_TYPE>.png,見
## GameEnums.base_building_background_path()),玩家按「離開」選項才返回
## Scenes/Base/base.tscn。建築內部真正的內政操作介面之後再設計,目前先只提供離開
## 這一個出口,不自動彈開 BaseActionPanel。


const BASE_SCENE_PATH := "res://Scenes/Base/base.tscn"


static func trigger(building: Building) -> void:
	var event := BaseBuildingEvent.new()
	event._start(building)


func _start(building: Building) -> void:
	goto_dialogue(_build_intro(building), "")


## 「離開」是選項而不是單純點擊推進,靠 DialogueChoice.next_scene_path 直接指定
## 返回場景,不需要額外的 on_selected lambda。
func _build_intro(building: Building) -> Dialogue:
	var narrator := DialogueSpeaker.new("narrator", "", "", GameEnums.DialogueSide.NARRATOR)
	var choices: Array[DialogueChoice] = [
		DialogueChoice.new("離開", BASE_SCENE_PATH),
	]
	var lines: Array[DialogueLine] = [
		DialogueLine.new(narrator.id, "你走進了%s。" % building.name, choices),
	]
	return Dialogue.new([narrator], lines, GameEnums.base_building_background_path(building.type))
