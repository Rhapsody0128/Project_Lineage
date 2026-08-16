class_name FaceController
extends RefCounted

const FACE_DIR := "res://Images/Face/"
const MALE_FACE_DIR := FACE_DIR + "Male/"
const FEMALE_FACE_DIR := FACE_DIR + "Female/"
const OTHER_FACE_DIR := FACE_DIR + "Other/"
const FACE_EXTENSIONS := ["jpg", "jpeg", "png"]

const BABY_FACE_PATH := OTHER_FACE_DIR + "baby.jpg"
const BOY_FACE_PATH := OTHER_FACE_DIR + "boy.png"
const GIRL_FACE_PATH := OTHER_FACE_DIR + "girl.png"
## 1~3 歲用固定的 baby 頭像,超過此年齡才依性別分 boy/girl
const CHILD_FACE_MAX_AGE := 3

## 依性別掃描 Images/Face/Male 或 Images/Face/Female 資料夾,隨機回傳一張頭像的資源路徑(字串)。
## 只回傳路徑,實際載入成 Texture2D 交給 Scenes 層(System 不碰畫面資源載入)。
static func get_random_face_path(gender: GameEnums.Gender) -> String:
	var dir_path := MALE_FACE_DIR if gender == GameEnums.Gender.MALE else FEMALE_FACE_DIR
	var paths := _list_face_paths(dir_path)
	if paths.is_empty():
		return ""
	return Util.get_random_from_array(paths)

## 小孩頭像:1~3 歲固定用 baby,4 歲起依性別分 boy/girl,一路頂到
## CharacterController.MIN_AGE(見 Character.age_up() 每年呼叫這裡刷新 face_path)——
## 不寫死到 14 歲,是為了跟成人隨機池的起始年齡無縫銜接,日後調整 MIN_AGE 不會在中間
## 空出一段沒有頭像規則的年齡。
static func get_child_face_path(age: int, gender: GameEnums.Gender) -> String:
	if age <= CHILD_FACE_MAX_AGE:
		return BABY_FACE_PATH
	return BOY_FACE_PATH if gender == GameEnums.Gender.MALE else GIRL_FACE_PATH

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
