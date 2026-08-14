extends Control

func _on_start_pressed() -> void:
	var error := get_tree().change_scene_to_file("res://Scenes/Battle/battle.tscn")
	if error != OK:
		printerr("Error changing scene to battle: ", error)


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_reports_pressed() -> void:
	var error := get_tree().change_scene_to_file("res://Scenes/BattleReportList/battle_report_list.tscn")
	if error != OK:
		printerr("Error changing scene to battle report list: ", error)
