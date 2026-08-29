extends Node

## 玩家根據地目前在大地圖上的座標——單一事實來源。根據地位置原本比照城鎮/城堡的慣例,
## 寫死一份 Vector2 快照在 System/map/map_object.gd 裡,但城鎮/城堡是美術擺好後不會再變的
## 定點,根據地現在已經開放玩家遷移(見 System/base/base_relocation_rule.gd、
## Scenes/Map/world_inner.gd 的 _apply_relocation()),不能沿用同一套「寫死常數」的做法,
## 所以改存在這個 autoload。Scenes/Base/base_inner.gd 讀這裡決定要顯示哪張地形背景圖
## (見 GameEnums.base_interior_background_path())。
##
## 注意跟城鎮/城堡不同,BASE 的同步方向是反過來的:world_inner.tscn 場景檔本身只是
## Base 節點最初擺放的座標,不會記得玩家遷移後的結果(切場景/重新載入都會回到 .tscn
## 寫死的初始值)——world_inner.gd._sync_map_object_positions() 對 BASE 類型改成用這裡的
## position 覆寫回場景節點,而不是像城鎮/城堡那樣讀節點目前位置存進資料,見該函式註解。
##
## 還沒有確定座標時(全新遊戲、還沒讀過存檔也還沒進過大地圖)不寫死一份常數在這裡
## 當備援——那樣每次美術/企劃在 world_inner.tscn 裡拖動 Base 節點調整定位,都要記得
## 回來同步改這個常數,很容易漏改導致兩邊對不上。改成 has_value 旗標:世界地圖第一次
## 進場、發現還沒有確定座標時,直接把 Base 節點「當下」擺放的位置回填進來當定案值
## (見 world_inner.gd._sync_map_object_positions()),之後才開始套用「這裡的值覆寫回
## 節點」的既有規則。

var position: Vector2 = Vector2.ZERO
## 是否已經有確定座標——見上方欄位註解。讀檔讀到存檔裡的座標,或大地圖第一次進場時
## 回填 Base 節點目前位置,都會把這個設成 true。
var has_value: bool = false

## 玩家是否正處於「遷移根據地」選點模式——true 時 Scenes/Map/world_inner.gd 的點擊處理
## 會改成「挑選新根據地座標」而不是一般的移動/進入地點(見該檔案 _handle_click_to_move()
## 的分支)。Scenes/MapLocation/map_location.gd 的「遷移根據地」按鈕按下時設為 true 並切去
## 大地圖,選點成功套用或玩家按 Esc 取消都會改回 false。是選點流程的暫時性 session 狀態,
## 不需要存檔(關遊戲重開視同取消)。
var is_relocating: bool = false


## Vector2 存成 [x, y] 陣列,比照 Scripts/Autoload/map_session_store.gd 的既有慣例。
## is_relocating 不存——選點模式是暫時性 session 狀態,見上方欄位註解。還沒有確定座標時
## (has_value 仍是 false)存空字典,讀檔時才不會把「還沒定案」誤存成 Vector2.ZERO 這個
## 假座標。
func to_save_data() -> Dictionary:
	if not has_value:
		return {}
	return {"position": [position.x, position.y]}


func load_save_data(data: Dictionary) -> void:
	var p: Array = data.get("position", [])
	if p.size() != 2:
		return
	position = Vector2(p[0], p[1])
	has_value = true
