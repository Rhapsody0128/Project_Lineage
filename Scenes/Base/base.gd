extends Control

## Base 場景的外層排版殼:比照 Scenes/Map/map.gd,只負責「HeaderBar 固定貼頂 + 下方
## BASE_VIEWPORT(SubViewport)顯示根據地世界」這件事,不碰任何建築規則/座標判定——
## 那些全部封裝在獨立場景檔 Scenes/Base/base_inner.tscn(script 見 base_inner.gd),
## 這裡只是把它 instance 進 BASE_VIEWPORT 底下顯示,節點命名為 BASE_INNER。美術要調整
## 建築範圍/背景,直接開 base_inner.tscn 就是一般的 2D 場景編輯,完全不受這裡
## SubViewport 尺寸的限制——不要開 base.tscn 改內容。
##
## SubViewportContainer 一定要開 stretch=true——關掉會讓 Godot 把它的最小尺寸直接等於
## 子 SubViewport.size(Godot 內建行為),容器永遠至少跟 SubViewport 一樣大,沒辦法真的
## 縮成 HeaderBar 底下那塊小範圍(見 Scenes/Map/map.gd 開頭註解,Map 版本先前就是踩了
## 這個坑才把鏡頭釘死)。開 stretch=true 後容器尺寸完全由這裡的錨點決定,Godot 也會自動
## 把子 SubViewport.size 隨容器改變即時同步。
##
## 「離開」按鈕放在這層(不放進 BASE_VIEWPORT),理由跟 HeaderBar 一致:這是畫面
## chrome(離開整個根據地畫面),不是根據地世界本身的內容,固定位置不應該因為
## SubViewport 尺寸而跟著跑——世界內容完全不需要知道 HeaderBar/離開鈕佔了多少空間,
## 兩者用同一個 Control 座標系(整個視窗),互不影響。

const _LEAVE_BUTTON_OFFSET := Rect2(1465.0, 825.0, 140.0, 60.0)
## 「全部派遣」「全部召回」跟「離開」同一排,由右往左排列,兩者中間各留 20px 間距——
## 跟「離開」一樣是畫面 chrome(整個根據地全部 12 棟生產建築一次處理),不是根據地世界
## 內容,固定位置不受 BASE_VIEWPORT 尺寸影響,理由見上方檔案開頭註解。
const _RECALL_ALL_BUTTON_OFFSET := Rect2(1305.0, 825.0, 140.0, 60.0)
const _AUTO_DISPATCH_ALL_BUTTON_OFFSET := Rect2(1145.0, 825.0, 140.0, 60.0)

@onready var sub_viewport_container: SubViewportContainer = $SubViewportContainer


func _ready() -> void:
	## HeaderBar 高度是唯一真相來源(Scripts/UI/header_bar.gd 的 HEIGHT),SubViewportContainer
	## 要讓出的頂部空間直接讀這個常數,不在 .tscn 裡另外寫死一份數字。
	sub_viewport_container.offset_top = HeaderBar.HEIGHT

	var header_bar := HeaderBar.new()
	add_child(header_bar)
	header_bar.add_status_button()

	_build_auto_dispatch_all_button()
	_build_recall_all_button()
	_build_leave_button()


func _build_chrome_button(text: String, offset: Rect2) -> Button:
	var button := Button.new()
	button.text = text
	button.offset_left = offset.position.x
	button.offset_top = offset.position.y
	button.offset_right = offset.position.x + offset.size.x
	button.offset_bottom = offset.position.y + offset.size.y
	UiStyle.apply_wood_plaque_button(button, 24.0, 12.0)
	button.add_theme_font_size_override("font_size", 22)
	add_child(button)
	return button


func _build_leave_button() -> void:
	var leave_button := _build_chrome_button("離開", _LEAVE_BUTTON_OFFSET)
	leave_button.pressed.connect(_on_leave_button_pressed)


## 依 AutoDispatchRule 規則,依 BuildingLibrary.get_all() 固定順序(已按產出難易度由易到
## 難排列,見 GameEnums.BuildingType 開頭註解)逐棟把目前閒置人力塞滿全部 12 棟生產建築的
## 空缺工作格——人力不夠填滿全部空缺時,基礎易產的建築優先分配到人。
func _build_auto_dispatch_all_button() -> void:
	var button := _build_chrome_button("全部派遣", _AUTO_DISPATCH_ALL_BUTTON_OFFSET)
	button.pressed.connect(func() -> void:
		AutoDispatchRule.auto_dispatch_all()
	)


## 把全部 12 棟生產建築目前派駐的工作角色一次召回,不需二次確認——跟單一格子點頭像召回
## (base_action_panel.gd 的 _build_worker_slot())同一套直接生效的既有慣例。
func _build_recall_all_button() -> void:
	var button := _build_chrome_button("全部召回", _RECALL_ALL_BUTTON_OFFSET)
	button.pressed.connect(func() -> void:
		AutoDispatchRule.recall_all()
	)


## 回到根據地的 MapLocation 選單頁(不是直接回大地圖),交給 BaseLeaveEvent 先播一句
## castle_interior.png 收尾過場——MapSessionStore.entered_map_object_id 還留著,
## map_location.gd._find_entered_map_object() 能正確還原成「根據地」那一頁。
func _on_leave_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/MapLocation/map_location.tscn")
