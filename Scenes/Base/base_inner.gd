extends Node2D

## 根據地世界邏輯:比照 Scenes/Map/world_inner.gd 的角色分工,沒有走位/攝影機拖曳縮放
## (使用者已確認:直接點擊建築物,不做角色走到定點——見計畫)。背景圖原始尺寸
## 1024x559,靠根節點 scale 撐滿「當下實際」的視窗大小,讓背景滿版鋪滿畫面(比照
## Dialogue 場景背景用 anchor 滿版的效果)。不能把 scale 寫死在 .tscn(算的是
## project.godot 設計時的 1920x1080),因為 HTML5 匯出在瀏覽器裡視窗比例不保證等於設計
## 比例(例如 1920x980)——`window/stretch/aspect="keep_height"` 只保證邏輯高度貼齊,
## 寬度會依實際視窗比例變動,寫死寬度會在較寬的視窗右側留空白。改成
## `_fit_background_to_viewport()` 在 `_ready()` 用 `get_viewport_rect().size` 即時算,
## 並接 `get_viewport().size_changed` 在視窗大小變動時重算(場景節點釋放時 Node 訊號會
## 自動斷線,不需手動 disconnect)。非等比縮放造成的些微變形可接受,因為
## Images/Base/base_<TERRAIN>.jpg 上沒有疊其他需要維持長寬比的圖層。BaseSystem.pick_building() 用
## Building.territory_polygon(使用者在原圖 1024x559 像素座標點出來的多邊形)比對
## get_local_mouse_position(),因為 Node2D.scale 就是 Godot 內建座標轉換,不管當下算出來
## 的 x/y 縮放比例是多少,click 判定一樣正確,不需要額外換算。建築本身不畫任何額外
## 圖層(不疊色塊、不顯示中文名稱標籤)——Images/Base/base_<TERRAIN>.jpg 的美術已經畫好建築長相,
## BuildingLibrary 的 territory_polygon 只用來做點擊命中判定(見
## BaseSystem.pick_building()),純資料、不需要對應的畫面節點。
##
## 這是獨立場景檔 Scenes/Base/base_inner.tscn 的根節點腳本,美術要調整建築範圍/背景,
## 直接開這個檔案就是一般的 2D 場景編輯,不受任何 SubViewport 尺寸限制。實際遊玩時這個
## 場景被 instance 進 Scenes/Base/base.tscn 的 BASE_VIEWPORT(SubViewport,見 base.gd)
## 底下,顯示在 HeaderBar 底下那塊範圍——但這支腳本完全不用知道這件事:
## `get_viewport_rect().size`(這裡的「viewport」就是那個 BASE_VIEWPORT)天生就是扣掉
## HeaderBar 後的實際可視大小。「離開」按鈕放外層 base.gd(比照 HeaderBar,是畫面
## chrome 不是根據地世界內容),原因見該檔案開頭註解。

@onready var background: TextureRect = $Background

var _base_system := BaseSystem.new()
var _buildings: Array[Building] = []


func _ready() -> void:
	_buildings = BuildingLibrary.get_all()

	_load_background_texture()
	_fit_background_to_viewport()
	get_viewport().size_changed.connect(_fit_background_to_viewport)

	_reopen_building_panel_if_requested()


## 從 Scenes/Tech/tech_tree.gd 返回時,用 SceneHandoffStore 交接「要重開哪一棟建築的
## ActionPanel」——go_back() 是整個場景重新載入,ActionPanel 本身雖然是 autoload 不會被
## 釋放,但內容已經被 _open_tech_tree() 清掉了,要重新呼叫 open_action_panel() 才會
## 看起來「依然在科學研究所」。
func _reopen_building_panel_if_requested() -> void:
	var handoff := SceneHandoffStore.take(TechTree.REOPEN_BUILDING_MAILBOX_KEY)
	if handoff == null:
		return
	var building_type: int = handoff.payload
	for building in _buildings:
		if building.type == building_type:
			BaseBuildingEvent.open_action_panel(building)
			return


## 依根據地在大地圖上的實際座標(BaseLocationStore,見該檔案檔頭註解——根據地之後會開放
## 玩家遷移,不是 MapObject.get_all() 那種寫死快照)查 MapTerrainMask 判定地形,換成對應的
## Images/Base/base_<TERRAIN>.jpg(六張地形差分,見 GameEnums.base_interior_background_path())。
## 不吃 MapObject.nation(那個欄位目前暫定 LION,是別的功能——玩家尚未開放自身國家血統
## 選擇——借用的預設值,不代表根據地實際座落的地形)。查不到地形(理論上不會發生,根據地
## 座標本來就落在陸地上)就退回 PLAINS 當保底。
func _load_background_texture() -> void:
	var terrain_type: int = GameEnums.TerrainType.PLAINS
	var nation := MapTerrainMask.nation_at(BaseLocationStore.position)
	if nation != -1:
		terrain_type = GameEnums.bloodline_nation_terrain(nation)
	background.texture = load(GameEnums.base_interior_background_path(terrain_type)) as Texture2D


## 用背景貼圖的原始像素尺寸對「當下實際」的視窗大小算出 x/y 縮放比例,取代寫死的
## scale 數值,見上方檔案開頭註解為什麼不能寫死。
func _fit_background_to_viewport() -> void:
	var texture_size := background.texture.get_size()
	var viewport_size := get_viewport_rect().size
	scale = viewport_size / texture_size


func _process(_delta: float) -> void:
	_update_hover_cursor()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var picked := _base_system.pick_building(get_local_mouse_position(), _buildings)
		if picked != null:
			BaseBuildingEvent.trigger(picked)


## 滑鼠懸停在可點擊的建築上時換成手指游標,跟 Scenes/Map/world_inner.gd 的
## _update_hover_cursor() 同一套邏輯;離開場景要記得還原(見 _exit_tree()),否則其他
## 場景會沿用這裡設定的游標。
func _update_hover_cursor() -> void:
	var hovered := _base_system.pick_building(get_local_mouse_position(), _buildings)
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if hovered != null else Input.CURSOR_ARROW)


func _exit_tree() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
