extends Control

## Map 場景的外層排版殼:只負責「HeaderBar 固定貼頂 + 下方 WORLD_VIEWPORT
## (SubViewport)顯示地圖世界」這件事,不碰任何地圖規則/座標邏輯——那些全部封裝在
## 獨立場景檔 Scenes/Map/world_inner.tscn(script 見 world_inner.gd),這裡只是把它
## instance 進 WORLD_VIEWPORT 底下顯示,節點命名為 WORLD_INNER。美術/企劃要調整
## Town/Castle 位置、縮放看整張地圖,直接開 world_inner.tscn 就是一般的 2D 場景編輯,
## 完全不受這裡 SubViewport 尺寸的限制——不要開 map.tscn 改位置。
##
## 為什麼不直接把地圖世界節點往下位移來閃開 HeaderBar:地圖用 Camera2D +
## MapTerrainMask 一整套「世界座標」邏輯(MapObject 座標、地形 mask 採樣都假設世界
## 座標原點在地圖左上角),如果只是位移該節點,它的本地座標(Town/Castle 節點座標)
## 不會變,但 camera.get_global_mouse_position() 傳回的卻是「全域」座標(含這個位移),
## 兩邊會對不起來——正是先前 map.tscn 手動把 Background/Terrain 貼圖往下搬卻沒同步搬
## 地形 mask 採樣座標,導致點擊/地形判定跟畫面顯示對不上的同一種錯位問題。改用
## SubViewport 包住整個地圖世界,SubViewport 內部的 size/滑鼠世界座標天生就是它自己的
## 局部座標系,地圖世界完全不用知道 HeaderBar 佔了多少空間,也就沒有座標系兜不起來的
## 風險。
##
## Scenes/Base/base.gd 用的是同一套外層殼(HeaderBar + SubViewportContainer +
## BASE_VIEWPORT)架構,兩邊改動時互相對照。
##
## SubViewportContainer 一定要開 stretch=true——關掉會讓 Godot 把它的最小尺寸直接等於
## 子 SubViewport.size(Godot 內建行為,不開 stretch 時 SubViewportContainer 的
## get_minimum_size() 會回傳子 SubViewport 目前的大小),等於容器永遠至少跟 SubViewport
## 一樣大,沒辦法真的縮成 HeaderBar 底下那塊小範圍(之前關掉 stretch 讓編輯器能看到
## 8000x4500 整張地圖,結果容器被撐到跟地圖一樣大,鏡頭邊界夾制量到的可視範圍直接蓋過
## 整張地圖,鏡頭因此被強制釘死在正中央、WASD/拖曳完全沒反應)。開 stretch=true 後容器
## 尺寸完全由這裡的錨點決定,SubViewport 的算圖結果只是被縮放貼上去,兩者互不影響;
## stretch=true 同時會讓 Godot 自動把子 SubViewport.size 隨容器改變即時同步,不用自己
## 接 resized 訊號手動處理。WORLD_VIEWPORT 的尺寸因此會被鎖回螢幕大小,不適合在裡面直接
## 編輯——這正是 WORLD_INNER 拆成獨立場景檔的原因,見上方說明。

@onready var sub_viewport_container: SubViewportContainer = $SubViewportContainer


func _ready() -> void:
	## HeaderBar 高度是唯一真相來源(Scripts/UI/header_bar.gd 的 HEIGHT),SubViewportContainer
	## 要讓出的頂部空間直接讀這個常數,不在 .tscn 裡另外寫死一份數字。
	sub_viewport_container.offset_top = HeaderBar.HEIGHT

	var header_bar := HeaderBar.new()
	add_child(header_bar)
	header_bar.add_status_button()

	BgmStore.play_map()


## 場景離開(切去 MapLocation/Battle 等任何其他場景)時淡出音樂,避免音樂被瞬間切斷
## 的割裂感——見 BgmStore.fade_out()。
func _exit_tree() -> void:
	BgmStore.fade_out()
