extends Node

## 場景轉場歷史堆疊:要切場景的地方一律呼叫 go_to() 而不要直接呼叫
## get_tree().change_scene_to_file(),它會把目前場景推進堆疊;之後在該場景的
## 返回鍵改呼叫 go_back(),從堆疊頂端彈出、切過去——連續多層轉場(例如大地圖
## → 隊伍編輯 → 開始戰鬥)才能一路照原路退回去,不會退第二層時發現記錄已經被
## 上一層覆蓋掉、錯誤地掉回預設值。
##
## Dialogue 這種只是路過的中繼場景不會自己呼叫 go_to(),不會被算進堆疊裡(中繼
## 場景本身不是一個能「返回」的頁面)。如果某段流程會先繞去中繼場景才抵達真正
## 目的地(例如 MapLocation 城門守衛的「闖進去」流程繞去 Dialogue 才到 Battle),
## 由發起這趟轉場的呼叫端在切場景前自己呼叫 push_return_scene_path(),把邏輯上
## 的上一頁手動推進堆疊,見 map_location.gd 的 _on_town_button_pressed()。

var _history: Array[String] = []


func push_return_scene_path(scene_path: String) -> void:
	_history.push_back(scene_path)


func go_to(scene_path: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree.current_scene != null:
		_history.push_back(tree.current_scene.scene_file_path)
	var error := tree.change_scene_to_file(scene_path)
	if error != OK:
		printerr("Error changing scene to ", scene_path, ": ", error)


func go_back(default_scene_path: String = "res://Scenes/main.tscn") -> void:
	var target: String = _history.pop_back() if not _history.is_empty() else default_scene_path
	var tree := Engine.get_main_loop() as SceneTree
	var error := tree.change_scene_to_file(target)
	if error != OK:
		printerr("Error changing scene to ", target, ": ", error)
