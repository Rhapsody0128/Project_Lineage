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

@onready var sub_viewport_container: SubViewportContainer = $SubViewportContainer


func _ready() -> void:
	## HeaderBar 高度是唯一真相來源(Scripts/UI/header_bar.gd 的 HEIGHT),SubViewportContainer
	## 要讓出的頂部空間直接讀這個常數,不在 .tscn 裡另外寫死一份數字。
	sub_viewport_container.offset_top = HeaderBar.HEIGHT

	var header_bar := HeaderBar.new()
	add_child(header_bar)
	header_bar.add_status_button()

	_build_leave_button()


func _build_leave_button() -> void:
	var leave_button := Button.new()
	leave_button.text = "離開"
	leave_button.offset_left = _LEAVE_BUTTON_OFFSET.position.x
	leave_button.offset_top = _LEAVE_BUTTON_OFFSET.position.y
	leave_button.offset_right = _LEAVE_BUTTON_OFFSET.position.x + _LEAVE_BUTTON_OFFSET.size.x
	leave_button.offset_bottom = _LEAVE_BUTTON_OFFSET.position.y + _LEAVE_BUTTON_OFFSET.size.y
	UiStyle.apply_wood_plaque_button(leave_button, 24.0, 12.0)
	leave_button.add_theme_font_size_override("font_size", 22)
	leave_button.pressed.connect(_on_leave_button_pressed)
	add_child(leave_button)


## 回到根據地的 MapLocation 選單頁(不是直接回大地圖),交給 BaseLeaveEvent 先播一句
## castle_interior.png 收尾過場——MapSessionStore.entered_map_object_id 還留著,
## map_location.gd._find_entered_map_object() 能正確還原成「根據地」那一頁。
func _on_leave_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/MapLocation/map_location.tscn")
