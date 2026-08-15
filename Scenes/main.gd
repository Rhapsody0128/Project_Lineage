extends Control

func _on_map_pressed() -> void:
	var error := get_tree().change_scene_to_file("res://Scenes/Map/Map.tscn")
	if error != OK:
		printerr("Error changing scene to map: ", error)


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_reports_pressed() -> void:
	NavigationStore.go_to("res://Scenes/BattleReportList/battle_report_list.tscn")
