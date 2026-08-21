extends Node

## 遊戲啟動時把 addons/asset_bundle 匯出時切出去的 subpackage 掛載回來,讓
## res://Images/Dialogue/... 之後的 load() 能正常讀到。Images/Dialogue 依子資料夾拆成多包
## (各自的 AssetBundle 資源見 Images/Dialogue/Base/Base.tres、Castle/Castle.tres、
## Map/Castle/MapCastle.tres、Map/Landform/MapLandform.tres、Map/Town/MapTown.tres、
## Town/Town.tres),沒有拆包的只剩 Images/Dialogue/Map/Base.png 這一張散圖,留在主 pck。
## 編輯器內直接跑遊戲時 Images/Dialogue 本來就在專案目錄裡,不需要掛載。
##
## Web 平台下載這幾包(合計上百 MB)需要真的時間,先前放任它們在背景默默下載,玩家
## 常常在下載完成前就走到需要圖片的畫面,圖片會晚到才「跳出來」。改成
## Scenes/Boot/boot.gd 在真正進主選單前擋著等 loading_finished,讓這段下載併入開場
## 的載入畫面,而不是進了遊戲之後才發現圖片是空的。

signal loading_finished

const BUNDLE_NAMES : PackedStringArray = [
	"Base", "Castle", "MapCastle", "MapLandform", "MapTown", "Town",
]

## 所有追蹤 log 都加這個前綴,方便在瀏覽器 Console 用關鍵字篩選排查。
const LOG_PREFIX := "[AssetBundleLoader]"

## Boot 場景用這個判斷要不要秀載入畫面/何時可以切去主選單。
var is_finished : bool = false

var _pending_count : int = 0
var _active_requests : Array[HTTPRequest] = []
var _bundle_total_bytes : Dictionary[String, int] = {}
var _bundle_downloaded_bytes : Dictionary[String, int] = {}

func _ready() -> void:
	print(LOG_PREFIX, " _ready, editor=", OS.has_feature("editor"), " web=", OS.has_feature("web"))
	if OS.has_feature("editor"):
		_mark_finished()
		return

	if !OS.has_feature("web"):
		for bundle_name in BUNDLE_NAMES:
			_load_bundle_native("%s.pck" % bundle_name)
		_mark_finished()
		return

	_pending_count = BUNDLE_NAMES.size()
	for bundle_name in BUNDLE_NAMES:
		var package_name : String = "%s.pck" % bundle_name
		_bundle_total_bytes[package_name] = 0
		_bundle_downloaded_bytes[package_name] = 0
		# 不 await——讓六個 bundle 同時平行下載,而不是一個接一個排隊。序列下載時,
		# 排在後面的 bundle(例如 MapTown)要等前面所有 bundle 都下載完才會開始,
		# 玩家若在那之前就走到對應場景,圖片會因為 pck 還沒掛載而讀不到(res://
		# 路徑對 ResourceLoader 來說是「No loader found」,不是單純的 404)。
		_load_bundle_web(package_name)

## Web 下載期間逐幀輪詢每個 HTTPRequest 的已下載/總大小,給 get_progress() 用。
func _process(_delta: float) -> void:
	if _active_requests.is_empty():
		return
	for request in _active_requests:
		if !is_instance_valid(request):
			continue
		var package_name : String = request.get_meta("package_name")
		var body_size : int = request.get_body_size()
		if body_size > 0:
			_bundle_total_bytes[package_name] = body_size
		_bundle_downloaded_bytes[package_name] = request.get_downloaded_bytes()

## 0~1。非 Web 平台(編輯器/原生匯出)一律視為瞬間完成,回傳 1。Web 平台用「目前已知
## 總大小 vs 已下載」估算——尚未收到 Content-Length 的 bundle 用目前已下載量墊底,
## 避免分母是 0。
func get_progress() -> float:
	if !OS.has_feature("web"):
		return 1.0
	if _bundle_total_bytes.is_empty():
		return 0.0

	var total : int = 0
	var downloaded : int = 0
	for package_name in _bundle_total_bytes:
		var bundle_downloaded : int = _bundle_downloaded_bytes[package_name]
		total += maxi(_bundle_total_bytes[package_name], bundle_downloaded)
		downloaded += bundle_downloaded

	if total <= 0:
		return 0.0
	return clampf(float(downloaded) / float(total), 0.0, 1.0)

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
	print(LOG_PREFIX, " requesting ", package_name, " from ", remote_url)

	var request : HTTPRequest = HTTPRequest.new()
	# GitHub Pages(Fastly)回應會帶 gzip 壓縮,瀏覽器本身就會自動解壓縮——但 Godot
	# 的 HTTPRequest 預設 accept_gzip=true 還會再對(已經解壓縮過的)body 嘗試解一次
	# gzip,導致失敗回傳 RESULT_BODY_DECOMPRESS_FAILED(8)、body 變成 0 bytes。關掉讓
	# 它直接吃瀏覽器給的原始 bytes。
	request.accept_gzip = false
	request.set_meta("package_name", package_name)
	add_child(request)
	_active_requests.append(request)

	var error : int = request.request(remote_url)
	if error != OK:
		print(LOG_PREFIX, " request() rejected for ", remote_url, " error=", error)
		push_warning("Failed to request asset bundle: %s" % remote_url)
		_finish_bundle(request)
		return

	var response : Array = await request.request_completed

	var result : int = response[0]
	var response_code : int = response[1]
	var body : PackedByteArray = response[3]
	print(LOG_PREFIX, " response for ", package_name, " result=", result, " http_code=", response_code, " bytes=", body.size())
	if result != HTTPRequest.RESULT_SUCCESS || response_code != 200:
		push_warning("Failed to download asset bundle: %s" % remote_url)
		_finish_bundle(request)
		return

	var local_path : String = "user://%s" % package_name
	var file : FileAccess = FileAccess.open(local_path, FileAccess.WRITE)
	if file == null:
		print(LOG_PREFIX, " FileAccess.open failed for ", local_path, " error=", FileAccess.get_open_error())
		push_warning("Failed to write asset bundle: %s" % local_path)
		_finish_bundle(request)
		return
	file.store_buffer(body)
	file.close()

	var loaded : bool = ProjectSettings.load_resource_pack(local_path)
	print(LOG_PREFIX, " load_resource_pack(", local_path, ") = ", loaded)
	if !loaded:
		push_warning("Failed to load asset bundle: %s" % local_path)
	_finish_bundle(request)

## HTTPRequest.request() 要求絕對 URL(必須是 http(s):// 開頭),傳純相對路徑
## (例如 "subpackages/Base.pck")會直接被 _parse_url 判定失敗、連請求都送不出去——
## 這正是先前「所有 Dialogue 背景圖在 Web 都讀不到」的原因。改用目前頁面的實際網址
## (JavaScriptBridge.eval 讀 window.location.href)組出絕對路徑,才能在任何部署路徑
## (例如 GitHub Pages 的子路徑)下都正確解析。
func _resolve_web_bundle_url(package_name: String) -> String:
	var page_url : String = String(JavaScriptBridge.eval("window.location.href", true))
	print(LOG_PREFIX, " window.location.href = '", page_url, "'")
	return page_url.get_base_dir().path_join("subpackages").path_join(package_name)

## 不管單一 bundle 成功或失敗都要呼叫,否則失敗的 bundle 會讓 _pending_count
## 永遠扣不到 0,Boot 畫面卡住不會進主選單。
func _finish_bundle(request: HTTPRequest) -> void:
	var package_name : String = request.get_meta("package_name")
	_bundle_downloaded_bytes[package_name] = _bundle_total_bytes.get(package_name, _bundle_downloaded_bytes[package_name])
	_active_requests.erase(request)
	request.queue_free()

	_pending_count -= 1
	if _pending_count <= 0:
		_mark_finished()

func _mark_finished() -> void:
	is_finished = true
	print(LOG_PREFIX, " all bundles finished")
	loading_finished.emit()
