extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_start_pressed() -> void:
	print("Starting Battle...")
	var error = get_tree().change_scene_to_file("res://Scenes/Battle/battle.tscn") # ***请将此路径改为您的Battle场景的实际路径***
	if error != OK:
		printerr("Error changing scene to battle: ", error)


func _on_quit_pressed() -> void:
	print("Quitting Game...")
	get_tree().quit()


func _on_reports_pressed() -> void:
	var error = get_tree().change_scene_to_file("res://Scenes/BattleReportList/battle_report_list.tscn")
	if error != OK:
		printerr("Error changing scene to battle report list: ", error)
