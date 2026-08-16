class_name FaceController
extends RefCounted

const FACE_DIR := "res://Images/Face/"
const MALE_FACE_DIR := FACE_DIR + "Male/"
const FEMALE_FACE_DIR := FACE_DIR + "Female/"
const FACE_EXTENSIONS := ["jpg", "jpeg", "png"]

## 依性別掃描 Images/Face/Male 或 Images/Face/Female 資料夾,隨機回傳一張頭像的資源路徑(字串)。
## 只回傳路徑,實際載入成 Texture2D 交給 Scenes 層(System 不碰畫面資源載入)。
static func get_random_face_path(gender: GameEnums.Gender) -> String:
	var dir_path := MALE_FACE_DIR if gender == GameEnums.Gender.MALE else FEMALE_FACE_DIR
	var paths := _list_face_paths(dir_path)
	if paths.is_empty():
		return ""
	return Util.get_random_from_array(paths)

## export_filter=all_resources 匯出後,資料夾內原本 xxx.jpeg 的實際圖檔資源不會出現在
## 目錄列舉裡(改由內部 remap 表解析),列舉到的變成 xxx.jpeg.import 這個中繼資料檔;
## 若只認 FACE_EXTENSIONS 會全部濾掉,導致匯出後頭像全部讀不到、fallback 成佔位圖。
## 用 Dictionary 去重是因為編輯器裡兩者是各自存在的實體檔案,會被各自列舉到一次。
static func _list_face_paths(dir_path: String) -> Array[String]:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return []

	var seen: Dictionary = {}
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var resource_name := file_name
			if resource_name.get_extension().to_lower() == "import":
				resource_name = resource_name.get_basename()
			if resource_name.get_extension().to_lower() in FACE_EXTENSIONS:
				seen[resource_name] = true
		file_name = dir.get_next()
	dir.list_dir_end()

	var paths: Array[String] = []
	for resource_name in seen.keys():
		paths.append(dir_path + resource_name)
	return paths
