class_name BarracksGridExpandPanel
extends Control

# =========================================================
# 兵營「戰場擴充」分頁內容:花科研點數指定解鎖 PartyStore.grid(6x6 戰場編成格)裡的
# 任一格,花費依 GridExpansionRule.cost_for_next_cell() 隨已解鎖格數遞增。跟
# party_edit.gd 的「加大格子(D)」DEMO 按鈕(隨機解鎖、不扣任何資源)並存,互不影響——
# 那顆是開發除錯用,這裡才是正式的資源消耗管道,unlock_cells() 本身是聯集寫入。
#
# 不走 PartyEditGrid clone() 草稿編輯那一套(不需要「取消編輯」語意,單次確認即生效),
# 直接讀寫 PartyStore.grid;不重用 PartyEditBoard(那顆的座標常數是為 party_edit.tscn
# 那個滿版場景量身訂做),自己畫一份縮小版棋盤,透過 BoardTileRenderer 共用格線繪製、
# tile_color_fn 直接標示已解鎖/未解鎖。
# =========================================================

const TILE_SIZE := 56.0
## 說明文字放在標題列正下方(見 CLAUDE.md 這次需求),棋盤本身往下讓出這塊空間——
## BOARD_ORIGIN.y 因此不是單純的邊距,是「說明文字區塊高度 + 邊距」。
const HINT_TOP_MARGIN := 8.0
const HINT_HEIGHT := 44.0
const BOARD_ORIGIN := Vector2(8, HINT_TOP_MARGIN + HINT_HEIGHT + 8.0)
const UNLOCKED_COLOR := Color(0.55, 0.75, 0.45, 0.9)
const LOCKED_COLOR := Color(0.32, 0.32, 0.36, 0.9)

var _hint_label: RichTextLabel


func _ready() -> void:
	custom_minimum_size = Vector2(
		BOARD_ORIGIN.x * 2 + TILE_SIZE * PartyEditGrid.GRID_COLS,
		BOARD_ORIGIN.y + TILE_SIZE * PartyEditGrid.GRID_ROWS + 8.0
	)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)

	# RichTextLabel + bbcode [img] 標籤內嵌資源圖示,取代純文字「科研」二字(見 CLAUDE.md
	# 這次需求,同 header_bar.gd _build_resource_icon_label() 既有寫法)。
	_hint_label = RichTextLabel.new()
	_hint_label.bbcode_enabled = true
	_hint_label.fit_content = true
	_hint_label.scroll_active = false
	_hint_label.position = Vector2(BOARD_ORIGIN.x, HINT_TOP_MARGIN)
	_hint_label.custom_minimum_size = Vector2(TILE_SIZE * PartyEditGrid.GRID_COLS, HINT_HEIGHT)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_hint_label.add_theme_color_override("default_color", UiStyle.PARCHMENT_TEXT_COLOR)
	add_child(_hint_label)
	_refresh_hint()


func _draw() -> void:
	if PartyStore.grid == null:
		return
	var grid := PartyStore.grid
	BoardTileRenderer.draw_board(
		self, PartyEditGrid.GRID_COLS, PartyEditGrid.GRID_ROWS, TILE_SIZE, BOARD_ORIGIN,
		func(x: int, y: int) -> Color:
			return UNLOCKED_COLOR if grid.is_unlocked(Vector2i(x, y)) else LOCKED_COLOR
	)


func _refresh_hint() -> void:
	if PartyStore.grid == null:
		_hint_label.text = "尚未編成過隊伍，無法擴充戰場格"
		return
	var icon_tag := "[img=20x20]%s[/img]" % GameEnums.resource_type_icon_path(GameEnums.ResourceType.RESEARCH)
	var unlocked_count := PartyStore.grid.get_unlocked_cells().size()
	_hint_label.text = "目前 %s %d｜已解鎖 %d 格，點選灰色格子花費 %s 解鎖（下一格花費：%d）" % [
		icon_tag, BaseResourceStore.get_display_amount(GameEnums.ResourceType.RESEARCH),
		unlocked_count, icon_tag, GridExpansionRule.cost_for_next_cell(unlocked_count)
	]


func _on_gui_input(event: InputEvent) -> void:
	if PartyStore.grid == null:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return

	var local_pos: Vector2 = (event as InputEventMouseButton).position
	var cell := Vector2i(floori((local_pos.x - BOARD_ORIGIN.x) / TILE_SIZE), floori((local_pos.y - BOARD_ORIGIN.y) / TILE_SIZE))
	if cell.x < 0 or cell.x >= PartyEditGrid.GRID_COLS or cell.y < 0 or cell.y >= PartyEditGrid.GRID_ROWS:
		return
	if PartyStore.grid.is_unlocked(cell):
		return

	var unlocked_count := PartyStore.grid.get_unlocked_cells().size()
	var cost := GridExpansionRule.cost_for_next_cell(unlocked_count)
	if not BaseResourceStore.can_afford({GameEnums.ResourceType.RESEARCH: cost}):
		ConfirmDialog.notify("科研點數不足")
		return

	ConfirmDialog.ask("花費 %d 科研解鎖這一格？" % cost, func() -> void:
		BaseResourceStore.spend({GameEnums.ResourceType.RESEARCH: cost})
		PartyStore.grid.unlock_cells([cell])
		queue_redraw()
		_refresh_hint()
	)
