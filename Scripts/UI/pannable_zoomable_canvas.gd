class_name PannableZoomableCanvas
extends Control

## 手繪版面畫布共用基底:FamilyTreeCanvas/TechTreeCanvas 都是「自己算版面座標、手動
## position/size 每個子節點、覆寫 _draw() 畫連接線,放在 ScrollContainer 底下可拖曳
## 平移」的同一種寫法(見 CLAUDE.md「UI 共用寫法分類」)——這裡把共用的拖曳平移+雙指
## 縮放判定抽出來,子類別只要覆寫 _rebuild_at_zoom(),把原本 render() 裡的版面座標常數
## 乘上 `zoom` 重新算一次即可。
##
## 縮放刻意不用 Control.scale——ScrollContainer 的捲動範圍是依子節點的
## custom_minimum_size 算的,不會跟著 scale 一起變:子節點視覺放大了,捲動範圍卻還是
## 原本大小,縮到一定程度就會出現「捲不到但看得到」或「捲得到但整片是空的」的錯位。
## 改成每次 zoom 改變就整個重新算一次版面(`_rebuild_at_zoom()`,子類別內部把原本
## render() 用到的座標/字級常數乘上 zoom),custom_minimum_size 天生就是對的縮放後
## 尺寸,不會跟 ScrollContainer 的捲動範圍打架。節點數量在這兩個畫面都是中小規模
## (單一家族/單一科技分類),縮放手勢期間重建全部子節點的成本可以接受。
##
## 只支援觸控雙指縮放,刻意不接桌面滑鼠滾輪——滾輪在這兩個畫面原本就是
## ScrollContainer 內建的垂直捲動,疊上滾輪縮放會互搶輸入。

const ZOOM_MIN := 0.5
const ZOOM_MAX := 2.0
const DRAG_MOVE_THRESHOLD := 4.0

var zoom: float = 1.0

var _scroll_container: ScrollContainer
var _dragging: bool = false
var _drag_moved: bool = false
var _drag_distance: float = 0.0

## 雙指縮放狀態,寫法比照 Scenes/Map/world_inner.gd 的 _touch_points/_pinch_prev_distance
## ——key 是 InputEventScreenTouch.index,value 是該指目前螢幕座標。
var _touch_points: Dictionary = {}
var _pinch_prev_distance := 0.0


func _ready() -> void:
	_scroll_container = get_parent() as ScrollContainer


## 子類別覆寫:用目前 `zoom` 值重新算一次版面座標並重建子節點(比照子類別原本 render()
## 的收尾,一律要重設 custom_minimum_size 讓 ScrollContainer 抓到正確捲動範圍)。
func _rebuild_at_zoom() -> void:
	pass


## 拖曳平移沿用原本兩份重複貼上的寫法(用 _input() 而非 _gui_input(),不受子節點
## mouse_filter 影響),額外加上雙指縮放判定。
func _input(event: InputEvent) -> void:
	if _scroll_container == null:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if not _scroll_container.get_global_rect().has_point(event.position):
				return
			_dragging = true
			_drag_moved = false
			_drag_distance = 0.0
		else:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		var delta: Vector2 = event.relative
		_drag_distance += delta.length()
		if _drag_distance > DRAG_MOVE_THRESHOLD:
			_drag_moved = true
		_scroll_container.scroll_horizontal -= int(delta.x)
		_scroll_container.scroll_vertical -= int(delta.y)
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			_touch_points[touch_event.index] = touch_event.position
			if _touch_points.size() == 2:
				# 第二指按下才真正進入雙指縮放,順便打斷單指拖曳判定,避免放開時誤觸
				# 卡片點擊(比照 world_inner.gd 同一處寫法)。
				_pinch_prev_distance = _touch_points_distance()
				_dragging = false
		else:
			_touch_points.erase(touch_event.index)
			if _touch_points.size() < 2:
				_pinch_prev_distance = 0.0
	elif event is InputEventScreenDrag:
		var drag_event := event as InputEventScreenDrag
		if _touch_points.has(drag_event.index):
			_touch_points[drag_event.index] = drag_event.position
		if _touch_points.size() == 2 and _pinch_prev_distance > 0.0:
			var new_distance := _touch_points_distance()
			if new_distance > 0.0:
				_apply_pinch_zoom(new_distance / _pinch_prev_distance, _touch_points_center())
				_pinch_prev_distance = new_distance


func _touch_points_distance() -> float:
	var positions := _touch_points.values()
	return (positions[0] as Vector2).distance_to(positions[1] as Vector2)


func _touch_points_center() -> Vector2:
	var positions := _touch_points.values()
	return ((positions[0] as Vector2) + (positions[1] as Vector2)) / 2.0


## 縮放中心維持在兩指中點對應的內容點上:先把兩指中點換算成「跟目前 zoom 無關」的
## 版面基準座標,套用新 zoom 重建版面後,再反推新的 scroll 值讓同一個內容點還是落在
## 兩指中點下面。重建版面到 ScrollContainer 抓到新捲動範圍中間有極短暫的一幀時差
## (跟 world_inner.gd 縮放後硬夾相機邊界屬於同一類已知簡化),不影響功能正確性。
func _apply_pinch_zoom(factor: float, center_screen_pos: Vector2) -> void:
	var new_zoom: float = clamp(zoom * factor, ZOOM_MIN, ZOOM_MAX)
	if is_equal_approx(new_zoom, zoom):
		return

	var origin := _scroll_container.get_global_rect().position
	var local_before: Vector2 = center_screen_pos - origin + Vector2(
		_scroll_container.scroll_horizontal, _scroll_container.scroll_vertical
	)
	var baseline := local_before / zoom

	zoom = new_zoom
	_rebuild_at_zoom()

	var local_after := baseline * zoom
	var target_scroll := local_after - (center_screen_pos - origin)
	_scroll_container.scroll_horizontal = int(target_scroll.x)
	_scroll_container.scroll_vertical = int(target_scroll.y)
