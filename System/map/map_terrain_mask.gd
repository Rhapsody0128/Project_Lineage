class_name MapTerrainMask
extends RefCounted

## 大地圖地形/國家歸屬/可行走範圍判定,改用美術直接畫的一張全地圖色塊圖
## (Images/Map/map_terrain.png,Scenes/Map/map.tscn 裡的 Terrain TextureRect 疊在
## Background 上面顯示的就是同一張圖)當 mask 查詢,取代先前逐一手畫 Area2D 多邊形的
## 做法——冰原/平原兩塊手畫多邊形交界處實測重疊了 52564 平方單位,而且只覆蓋地圖一小塊
## 範圍,其餘地形沒有對應區域;色塊圖天生覆蓋全地圖、不會有多邊形重疊/留縫問題,美術
## 之後要調整地形範圍也只要改這張圖,不用回頭改 GDScript 裡的頂點座標。
##
## 圖片用六種血統國家代表色(見下方 NATION_COLORS)畫出各國地形範圍,顏色之外的部分
## (含全透明背景、山岳等障礙物在色塊中鏤空的白色部分)一律視為「不可行走」——山岳鏤空
## 不是獨立的第七種地形類型,只是「不可行走」的一種呈現方式,跟海面/地圖外圍空白共用
## 同一套判斷,呼叫端不需要分辨兩者差異,一律呼叫 is_walkable()/nation_at()。

## 顏色比對時 alpha 低於這個值直接判定不可行走——mask 圖背景/鏤空是全透明,邊緣抗鋸齒
## 會留下漸層 alpha,不能只看 alpha == 0。
const ALPHA_BLOCKED_THRESHOLD := 0.5

## 六個色塊顏色 → 血統國家(GameEnums.BloodlineNation),地形類型另外呼叫
## GameEnums.bloodline_nation_terrain() 換算,不重複維護第二份地形對照表。顏色數值
## 是美術原始 mask 圖(Images/Map/map_terrain.png)的實際色碼,鷹(白)刻意畫成灰色
## 跟全透明背景做視覺區隔,不是真的純白。
const NATION_COLORS: Dictionary = {
	GameEnums.BloodlineNation.LION: Color8(255, 0, 11),
	GameEnums.BloodlineNation.EAGLE: Color8(182, 182, 181),
	GameEnums.BloodlineNation.LEOPARD: Color8(255, 207, 0),
	GameEnums.BloodlineNation.BEAR: Color8(13, 121, 0),
	GameEnums.BloodlineNation.DRAGON: Color8(0, 21, 255),
	GameEnums.BloodlineNation.DEER: Color8(0, 255, 221),
}

## 跟 Scenes/Map/map.tscn 裡 Terrain(TextureRect)節點吃的是同一張圖——同一個 res://
## 路徑讓 Godot 資源快取共用同一份,不要另外複製一份資源或直接讀檔案系統路徑(那份在
## 匯出後的封裝版本裡不保證存在,見下方 _get_image() 改用 load() 走資源匯入管線)。
const MASK_PATH := "res://Images/Map/map_terrain.png"

## 靜態快取,整個執行期間只轉一次 Image(load() 命中 Godot 資源快取很快,但
## Texture2D.get_image() 每次呼叫都會重新解壓一份新的 Image,還是快取起來比較好)。
static var _image: Image = null


static func _get_image() -> Image:
	if _image == null:
		var texture: Texture2D = load(MASK_PATH)
		_image = texture.get_image()
	return _image


## 世界座標 → mask 圖片像素座標。x/y 分別依圖片實際寬高對 MapSystem.MAP_SIZE 的比例
## 換算(兩軸分開算,不要求圖片跟地圖長寬比完全一致)。
static func _world_to_pixel(pos: Vector2) -> Vector2i:
	var image := _get_image()
	var px := int(clamp(pos.x / MapSystem.MAP_SIZE.x * image.get_width(), 0, image.get_width() - 1))
	var py := int(clamp(pos.y / MapSystem.MAP_SIZE.y * image.get_height(), 0, image.get_height() - 1))
	return Vector2i(px, py)


## 這個世界座標所屬的血統國家,落在不可行走的地方(山岳鏤空/海面/地圖外)回傳 -1。
static func nation_at(pos: Vector2) -> int:
	var color := _get_image().get_pixelv(_world_to_pixel(pos))
	if color.a < ALPHA_BLOCKED_THRESHOLD:
		return -1
	var best_nation := -1
	var best_dist := INF
	for nation in NATION_COLORS:
		var dist: float = _color_distance(color, NATION_COLORS[nation])
		if dist < best_dist:
			best_dist = dist
			best_nation = nation
	return best_nation


## 只比對 RGB,忽略 alpha——mask 圖邊緣抗鋸齒的半透明像素,顏色本身仍應歸類到最接近的
## 那個國家色,alpha 只用來擋全透明的背景/鏤空(見 nation_at() 的門檻判斷)。
static func _color_distance(a: Color, b: Color) -> float:
	return (a.r - b.r) ** 2 + (a.g - b.g) ** 2 + (a.b - b.b) ** 2


## 這個世界座標可不可以站/走——查不到國家(山岳/海面/地圖外)就是不可行走。
static func is_walkable(pos: Vector2) -> bool:
	return nation_at(pos) != -1


## 從已知可行走的 from_pos,沿線段往 to_pos 方向逼近,回傳最後仍可行走的座標(對分搜尋
## 固定迭代次數,邊界誤差小到看不出來)——用於玩家/遊蕩敵人的移動目的地卡在陸地範圍內,
## 不會一步跨進山岳鏤空或海面。地形邊界不是凸集合,直線終點可行走不保證移動全程都不
## 出界,是已知簡化,跟先前多邊形版的限制相同。
static func clamp_segment_to_walkable(from_pos: Vector2, to_pos: Vector2) -> Vector2:
	if is_walkable(to_pos):
		return to_pos
	var inside := from_pos
	var outside := to_pos
	for i in range(12):
		var mid := inside.lerp(outside, 0.5)
		if is_walkable(mid):
			inside = mid
		else:
			outside = mid
	return inside
