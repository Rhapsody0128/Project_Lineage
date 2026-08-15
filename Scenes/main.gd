extends Control

## 保留未接按鈕,之後若要重開測試入口可直接重新連 pressed 訊號
func _on_start_pressed() -> void:
	NavigationStore.go_to("res://Scenes/Battle/battle.tscn")


func _on_party_edit_pressed() -> void:
	NavigationStore.go_to("res://Scenes/PartyEdit/party_edit.tscn")


func _on_map_pressed() -> void:
	var error := get_tree().change_scene_to_file("res://Scenes/Map/Map.tscn")
	if error != OK:
		printerr("Error changing scene to map: ", error)


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_reports_pressed() -> void:
	NavigationStore.go_to("res://Scenes/BattleReportList/battle_report_list.tscn")
