extends Node

## 遊戲啟動時把 addons/asset_bundle 匯出時切出去的 subpackage 掛載回來,讓
## res://Images/Dialogue/... 之後的 load() 能正常讀到。Images/Dialogue 依子資料夾拆成多包
## (各自的 AssetBundle 資源見 Images/Dialogue/Base/Base.tres、Castle/Castle.tres、
## Map/Castle/MapCastle.tres、Map/Landform/MapLandform.tres、Map/Town/MapTown.tres、
## Town/Town.tres),沒有拆包的只剩 Images/Dialogue/Map/Base.png 這一張散圖,留在主 pck。
## 編輯器內直接跑遊戲時 Images/Dialogue 本來就在專案目錄裡,不需要掛載。

const BUNDLE_NAMES : PackedStringArray = [
	"Base", "Castle", "MapCastle", "MapLandform", "MapTown", "Town",
]

func _ready() -> void:
	if OS.has_feature("editor"):
		return

	for bundle_name in BUNDLE_NAMES:
		var package_name : String = "%s.pck" % bundle_name
		if OS.has_feature("web"):
			await _load_bundle_web(package_name)
		else:
			_load_bundle_native(package_name)

## 原生平台(Windows/Linux/macOS):subpackage 就在執行檔旁邊的 subpackages/ 資料夾。
func _load_bundle_native(package_name: String) -> void:
	var executable_directory : String = OS.get_executable_path().get_base_dir()
	var package_path : String = executable_directory.path_join("subpackages").path_join(package_name)

	if !FileAccess.file_exists(package_path):
		push_warning("Asset bundle not found: %s" % package_path)
		return

	if !ProjectSettings.load_resource_pack(package_path):
		push_warning("Failed to load asset bundle: %s" % package_path)

## Web 平台沒有本機檔案系統可以直接讀,先用 HTTPRequest 把 subpackages/ 底下的檔案
## (跟 index.html 同一層,見 .github/workflows/build-and-deploy-web.yml)下載到 user://
## 再掛載——這段路徑假設頁面部署時 subpackages/ 資料夾有跟著一起發佈。
func _load_bundle_web(package_name: String) -> void:
	var remote_url : String = _resolve_web_bundle_url(package_name)

	var request : HTTPRequest = HTTPRequest.new()
	add_child(request)

	var error : int = request.request(remote_url)
	if error != OK:
		push_warning("Failed to request asset bundle: %s" % remote_url)
		request.queue_free()
		return

	var response : Array = await request.request_completed
	request.queue_free()

	var result : int = response[0]
	var response_code : int = response[1]
	var body : PackedByteArray = response[3]
	if result != HTTPRequest.RESULT_SUCCESS || response_code != 200:
		push_warning("Failed to download asset bundle: %s" % remote_url)
		return

	var local_path : String = "user://%s" % package_name
	var file : FileAccess = FileAccess.open(local_path, FileAccess.WRITE)
	if file == null:
		push_warning("Failed to write asset bundle: %s" % local_path)
		return
	file.store_buffer(body)
	file.close()

	if !ProjectSettings.load_resource_pack(local_path):
		push_warning("Failed to load asset bundle: %s" % local_path)

## HTTPRequest.request() 要求絕對 URL(必須是 http(s):// 開頭),傳純相對路徑
## (例如 "subpackages/Base.pck")會直接被 _parse_url 判定失敗、連請求都送不出去——
## 這正是先前「所有 Dialogue 背景圖在 Web 都讀不到」的原因。改用目前頁面的實際網址
## (JavaScriptBridge.eval 讀 window.location.href)組出絕對路徑,才能在任何部署路徑
## (例如 GitHub Pages 的子路徑)下都正確解析。
func _resolve_web_bundle_url(package_name: String) -> String:
	var page_url : String = String(JavaScriptBridge.eval("window.location.href", true))
	return page_url.get_base_dir().path_join("subpackages").path_join(package_name)
