class_name TechTreeCanvas
extends PannableZoomableCanvas

# =========================================================
# 單一分類(GameEnums.TechBranch)的科技樹本體:render(branch) 從 TechLibrary.get_by_branch()
# 拿到節點清單,自己算版面座標(x = rank 對應欄、y = 機制鏈對應列,見 _thread_rows())後
# 手動 position/size 每張卡片,再覆寫 _draw() 畫同一條機制鏈內前一層→這一層的連接線。
# 放在 tech_tree_panel.gd 的 ScrollContainer 底下,custom_minimum_size 撐開成整棵樹的
# 實際範圍,ScrollContainer 才滾得到全部內容——拖曳平移/雙指縮放/自算座標/覆寫 _draw()
# 的慣例跟 Scenes/FamilyTree/family_tree_canvas.gd 共用同一個基底類別
# PannableZoomableCanvas。
#
# 卡片內容比照需求:Rank、名稱、簡短描述(card_description,不寫確切數值)、花費、
# 解鎖鈕。確切數值/機率(effect_detail)目前沒有 UI 顯示位置,先留在 TechNode 資料裡
# 給之後的詳情面板/工具提示用。
# =========================================================

## 所有跟版面/字級相關的常數都是「zoom=1.0 時」的基準值,實際使用一律要乘上
## `zoom`——縮放不是靠 Control.scale,而是直接用縮放後的常數重新跑一次版面計算,
## 見 PannableZoomableCanvas 開頭註解。
const COL_WIDTH_BASE := 210.0
const ROW_HEIGHT_BASE := 130.0
const MARGIN_LEFT_BASE := 150.0
const MARGIN_TOP_BASE := 60.0
const CANVAS_MARGIN_BASE := 40.0

const CARD_WIDTH_BASE := 176.0
const CARD_HEIGHT_BASE := 96.0

const LINE_COLOR := Color(0.5, 0.52, 0.6, 0.9)
const LINE_WIDTH_BASE := 3.0

const RANK_LABEL_COLOR := Color(0.75, 0.78, 0.86)
const THREAD_LABEL_COLOR := Color(0.75, 0.78, 0.86)

var _branch: GameEnums.TechBranch = GameEnums.TechBranch.COMBAT
var _nodes: Array[TechNode] = []
var _rect_by_id: Dictionary = {}
var _row_by_thread: Dictionary = {}


func _ready() -> void:
	super._ready()
	TechStore.changed.connect(_on_tech_store_changed)


## 只有真的切換分類才重置 zoom——TechStore.changed 觸發的重新整理(解鎖科技後)也會
## 呼叫這裡,傳的是同一個 _branch,這種情況要保留玩家目前縮放的視角,不能每次解鎖
## 都把畫面彈回 zoom=1.0。
func render(branch: GameEnums.TechBranch) -> void:
	if branch != _branch:
		zoom = 1.0
	_branch = branch
	_rebuild_at_zoom()


func _rebuild_at_zoom() -> void:
	for child in get_children():
		child.queue_free()

	_nodes = TechLibrary.get_by_branch(_branch)
	_rect_by_id.clear()
	_row_by_thread.clear()

	var col_width := COL_WIDTH_BASE * zoom
	var row_height := ROW_HEIGHT_BASE * zoom
	var margin_left := MARGIN_LEFT_BASE * zoom
	var margin_top := MARGIN_TOP_BASE * zoom
	var card_width := CARD_WIDTH_BASE * zoom
	var card_height := CARD_HEIGHT_BASE * zoom

	var row_index := 0
	for node in _nodes:
		if not _row_by_thread.has(node.thread):
			_row_by_thread[node.thread] = row_index
			row_index += 1

	var max_right := 0.0
	var max_bottom := 0.0

	for thread_name in _row_by_thread:
		var row: int = _row_by_thread[thread_name]
		var label := Label.new()
		label.text = thread_name
		label.add_theme_color_override("font_color", THREAD_LABEL_COLOR)
		label.add_theme_font_size_override("font_size", maxi(1, int(14 * zoom)))
		label.position = Vector2(0.0, margin_top + row * row_height + card_height / 2.0 - 10.0 * zoom)
		label.custom_minimum_size = Vector2(margin_left - 20.0 * zoom, 20.0 * zoom)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		add_child(label)

	for rank in range(GameEnums.RankType.size()):
		var rank_label := Label.new()
		rank_label.text = "%s\nLv%d" % [GameEnums.rank_label(rank), rank + 1]
		rank_label.add_theme_color_override("font_color", RANK_LABEL_COLOR)
		rank_label.add_theme_font_size_override("font_size", maxi(1, int(12 * zoom)))
		rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rank_label.position = Vector2(margin_left + rank * col_width, 10.0 * zoom)
		rank_label.custom_minimum_size = Vector2(col_width, 40.0 * zoom)
		add_child(rank_label)

	for node in _nodes:
		var row: int = _row_by_thread[node.thread]
		var rect := Rect2(
			Vector2(margin_left + node.rank * col_width + (col_width - card_width) / 2.0, margin_top + row * row_height),
			Vector2(card_width, card_height)
		)
		_rect_by_id[node.id] = rect

		var card := _build_card(node)
		card.position = rect.position
		card.size = rect.size
		add_child(card)

		max_right = max(max_right, rect.position.x + rect.size.x)
		max_bottom = max(max_bottom, rect.position.y + rect.size.y)

	custom_minimum_size = Vector2(max_right + CANVAS_MARGIN_BASE * zoom, max_bottom + CANVAS_MARGIN_BASE * zoom)
	queue_redraw()


func _on_tech_store_changed() -> void:
	if is_inside_tree():
		render(_branch)


func _draw() -> void:
	var line_width := LINE_WIDTH_BASE * zoom
	for node in _nodes:
		if not node.has_prerequisite():
			continue
		if not _rect_by_id.has(node.prerequisite_id):
			continue
		var from_rect: Rect2 = _rect_by_id[node.prerequisite_id]
		var to_rect: Rect2 = _rect_by_id[node.id]
		var from_point := Vector2(from_rect.position.x + from_rect.size.x, from_rect.position.y + from_rect.size.y / 2.0)
		var to_point := Vector2(to_rect.position.x, to_rect.position.y + to_rect.size.y / 2.0)
		var lit := TechStore.is_unlocked(node.prerequisite_id)
		draw_line(from_point, to_point, LINE_COLOR if not lit else Color(0.85, 0.72, 0.35, 1.0), line_width)


func _build_card(node: TechNode) -> PanelContainer:
	var unlocked := TechStore.is_unlocked(node.id)
	var prereq_met := not node.has_prerequisite() or TechStore.is_unlocked(node.prerequisite_id)
	var level_met := BaseBuildingProgressStore.get_level(GameEnums.BuildingType.RESEARCH_INSTITUTE) >= node.required_institute_level()

	var bg_color := Color(0.16, 0.17, 0.22, 0.95)
	var border_color := Color(0.32, 0.35, 0.42, 1.0)
	if unlocked:
		border_color = Color(0.85, 0.72, 0.35, 1.0)
		bg_color = Color(0.2, 0.19, 0.14, 0.95)
	elif not prereq_met or not level_met:
		bg_color = Color(0.13, 0.13, 0.15, 0.9)
		border_color = Color(0.24, 0.25, 0.28, 1.0)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiStyle.bordered_panel(
		bg_color, border_color, maxi(1, roundi(2.0 * zoom)), roundi(8.0 * zoom), 10.0 * zoom, 8.0 * zoom
	))

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	card.add_child(column)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 6)
	column.add_child(top_row)

	var rank_badge := Label.new()
	rank_badge.text = GameEnums.rank_label(node.rank)
	rank_badge.add_theme_color_override("font_color", Color(0.85, 0.72, 0.35, 1.0) if unlocked else Color(0.7, 0.73, 0.8, 1.0))
	rank_badge.add_theme_font_size_override("font_size", maxi(1, int(13 * zoom)))
	top_row.add_child(rank_badge)

	var name_label := Label.new()
	name_label.text = node.display_name
	name_label.add_theme_color_override("font_color", Color(0.93, 0.93, 0.95, 1.0))
	name_label.add_theme_font_size_override("font_size", maxi(1, int(14 * zoom)))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	top_row.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = node.card_description
	desc_label.add_theme_color_override("font_color", Color(0.72, 0.74, 0.8, 1.0))
	desc_label.add_theme_font_size_override("font_size", maxi(1, int(11 * zoom)))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.custom_minimum_size = Vector2(0, 32 * zoom)
	column.add_child(desc_label)

	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 6)
	column.add_child(bottom_row)

	var cost_box := HBoxContainer.new()
	cost_box.add_theme_constant_override("separation", 3)
	cost_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.add_child(cost_box)

	var cost_icon := TextureRect.new()
	cost_icon.custom_minimum_size = Vector2(16, 16) * zoom
	cost_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cost_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cost_icon.texture = load(GameEnums.resource_type_icon_path(GameEnums.ResourceType.RESEARCH)) as Texture2D
	cost_box.add_child(cost_icon)

	var cost_label := Label.new()
	cost_label.text = str(node.cost)
	cost_label.add_theme_color_override("font_color", Color(0.8, 0.82, 0.6, 1.0))
	cost_label.add_theme_font_size_override("font_size", maxi(1, int(12 * zoom)))
	cost_box.add_child(cost_label)

	var button := Button.new()
	button.add_theme_font_size_override("font_size", maxi(1, int(11 * zoom)))
	if unlocked:
		button.text = "已解鎖"
		button.disabled = true
	elif not prereq_met:
		button.text = "需先解鎖前置"
		button.disabled = true
	elif not level_met:
		button.text = "研究所等級不足"
		button.disabled = true
	else:
		button.text = "解鎖"
		button.disabled = not TechStore.can_unlock(node)
		button.pressed.connect(func() -> void: TechStore.unlock(node))
	bottom_row.add_child(button)

	return card
