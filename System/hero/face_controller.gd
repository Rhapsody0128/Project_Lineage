class_name FaceController
extends RefCounted

const FACE_DIR := "res://Images/Face/"
const FACE_EXTENSIONS := ["jpg", "jpeg", "png"]

## 掃描 Images/Face 資料夾,隨機回傳一張頭像的資源路徑(字串)。
## 只回傳路徑,實際載入成 Texture2D 交給 Scenes 層(System 不碰畫面資源載入)。
static func get_random_face_path() -> String:
	var paths := _list_face_paths()
	if paths.is_empty():
		return ""
	return Util.get_random_from_array(paths)

static func _list_face_paths() -> Array[String]:
	var paths: Array[String] = []
	var dir := DirAccess.open(FACE_DIR)
	if dir == null:
		return paths

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension().to_lower() in FACE_EXTENSIONS:
			paths.append(FACE_DIR + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	return paths
