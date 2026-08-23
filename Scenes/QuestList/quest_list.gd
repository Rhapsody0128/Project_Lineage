extends Control

# =========================================================
# 任務列表:顯示 QuestStore.quests 目前所有任務,欄位為「描述 / 等級 / 進度 / 期限 /
# 放棄」——比照 Scenes/BattleReportList/battle_report_list.gd 的做法,清單項目整排用
# 程式碼動態產生,不另外開 row 用的子場景,欄寬用 size_flags_stretch_ratio 對齊靜態表頭
# (HeaderRow)的比例。任務要靠酒館老闆「詢問委託」(System/event/town/town_tavern_event.gd)
# 接,這個畫面本身沒有「生成」按鈕。
#
# 只有 IN_PROGRESS(進行中)的任務有「放棄」按鈕;COMPLETED(已完成)/EXPIRED(已過期)
# 都是永久保留的歷史紀錄,不提供任何按鈕、玩家沒有主動清除的管道,見 _build_action_slot()。
# QuestType.DELIVERY(交貨委託)IN_PROGRESS 時額外多一顆「繳交」鈕(見 _build_turn_in_button()),
# 資源不夠繳交時 disabled——連 BaseResourceStore.changed 一起刷新,存量變動當下就能反映
# 按鈕能不能按,不用等玩家離開再進這個畫面。
#
# 左側 Sidebar 三顆互斥按鈕(主線/支線/委託,見 quest_list.tscn 共用的 ButtonGroup,比照
# CLAUDE.md 提到 HeaderBar 倍速按鈕的做法)依 GameEnums.QuestCategory 篩選主清單只顯示
# 選中分類的任務——目前只有「討伐周邊強盜」這個 COMMISSION(委託任務)有實際內容,
# 主線/支線分頁先開著佔位,選到時顯示「尚無任務」。
# =========================================================

const ROW_MIN_HEIGHT := 64.0
const DESCRIPTION_COLUMN_STRETCH_RATIO := 6.0
const RANK_COLUMN_WIDTH := 70.0
const STATUS_COLUMN_WIDTH := 90.0
const DEADLINE_COLUMN_WIDTH := 150.0
const ABANDON_COLUMN_WIDTH := 90.0
const TURN_IN_COLUMN_WIDTH := 90.0
const TURN_IN_BUTTON_LABEL := "繳交"

const EXPIRED_COLOR := Color(0.9, 0.1, 0.1)
const IN_PROGRESS_COLOR := Color(0.1, 0.7, 0.1)
const COMPLETED_COLOR := Color(0.75, 0.6, 0.1)

@onready var main_panel: PanelContainer = $MainPanel
@onready var scroll_container: ScrollContainer = $MainPanel/Margin/VBox/ScrollContainer
@onready var quest_list: VBoxContainer = $MainPanel/Margin/VBox/ScrollContainer/QuestList
@onready var back_button: Button = $TopBar/BackButton
@onready var sidebar: PanelContainer = $Sidebar
@onready var main_quest_button: Button = $Sidebar/Margin/VBox/MainQuestButton
@onready var side_quest_button: Button = $Sidebar/Margin/VBox/SideQuestButton
@onready var commission_quest_button: Button = $Sidebar/Margin/VBox/CommissionQuestButton

## 目前選中的分頁,預設就是委託任務(見 quest_list.tscn 的 CommissionQuestButton
## button_pressed = true 初始外觀,兩邊要對得上)——目前唯一有實際內容的分類。
var _current_category: int = GameEnums.QuestCategory.COMMISSION


func _ready() -> void:
	UiStyle.apply_wood_plaque_button(back_button, 30.0, 10.0)
	back_button.add_theme_font_size_override("font_size", 16)
	UiStyle.apply_parchment_panel(main_panel, 1320.0, 740.0)
	UiStyle.apply_parchment_scrollbar(scroll_container)
	UiStyle.apply_parchment_panel(sidebar, 200.0, 740.0, 16.0, 20.0, 16.0, 20.0)
	for button in [main_quest_button, side_quest_button, commission_quest_button]:
		UiStyle.apply_wood_plaque_button(button, 20.0, 10.0)
		button.add_theme_font_size_override("font_size", 18)
	QuestStore.changed.connect(_refresh_list)
	BaseResourceStore.changed.connect(_refresh_list)
	_refresh_list()


func _on_category_button_pressed(category: int) -> void:
	_current_category = category
	_refresh_list()


func _refresh_list() -> void:
	for child in quest_list.get_children():
		child.queue_free()
	var visible_quests := QuestStore.quests.filter(func(quest: Quest) -> bool: return quest.category == _current_category)
	if visible_quests.is_empty():
		_spawn_empty_label()
		return
	for quest in visible_quests:
		_spawn_quest_row(quest)


func _spawn_empty_label() -> void:
	var label := Label.new()
	label.text = "（尚無任務）"
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", UiStyle.PARCHMENT_SUBTITLE_COLOR)
	quest_list.add_child(label)


func _spawn_quest_row(quest: Quest) -> void:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, ROW_MIN_HEIGHT)
	row.add_theme_stylebox_override("panel", UiStyle.parchment_row_style(
		UiStyle.PARCHMENT_ROW_BORDER, 2, 8, 16.0, 6.0
	))

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 20)
	row.add_child(content)

	var description_label := Label.new()
	description_label.text = "%s\n%s" % [QuestLibrary.title_for(quest), QuestLibrary.description_for(quest)]
	description_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description_label.size_flags_stretch_ratio = DESCRIPTION_COLUMN_STRETCH_RATIO
	description_label.add_theme_font_size_override("font_size", 15)
	description_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(description_label)

	var rank_label := Label.new()
	rank_label.text = GameEnums.rank_label(quest.rank)
	rank_label.custom_minimum_size = Vector2(RANK_COLUMN_WIDTH, 0)
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_label.add_theme_font_size_override("font_size", 15)
	rank_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	content.add_child(rank_label)

	var status_label := Label.new()
	status_label.text = GameEnums.quest_status_label(quest.status)
	status_label.custom_minimum_size = Vector2(STATUS_COLUMN_WIDTH, 0)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", _status_color(quest))
	content.add_child(status_label)

	var deadline_label := Label.new()
	deadline_label.text = QuestLibrary.deadline_text_for(quest)
	deadline_label.custom_minimum_size = Vector2(DEADLINE_COLUMN_WIDTH, 0)
	deadline_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	deadline_label.add_theme_font_size_override("font_size", 15)
	deadline_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_SUBTITLE_COLOR)
	content.add_child(deadline_label)

	content.add_child(_build_action_slot(quest))

	quest_list.add_child(row)


## 只有 IN_PROGRESS 給「放棄」按鈕(DELIVERY 額外多一顆「繳交」)——COMPLETED(永久歷史
## 紀錄)、EXPIRED(逾期結果一樣留著當紀錄)都不給任何按鈕,留一塊跟按鈕同寬的空白
## Control,讓這欄位置仍對齊表頭跟其他有按鈕的列。
func _build_action_slot(quest: Quest) -> Control:
	if quest.status != GameEnums.QuestStatus.IN_PROGRESS:
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(ABANDON_COLUMN_WIDTH + TURN_IN_COLUMN_WIDTH, 0)
		return spacer

	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	if quest.quest_type == GameEnums.QuestType.DELIVERY:
		box.add_child(_build_turn_in_button(quest))
	box.add_child(_build_abandon_button(quest))
	return box


func _build_abandon_button(quest: Quest) -> Button:
	var abandon_button := Button.new()
	abandon_button.text = "放棄"
	abandon_button.custom_minimum_size = Vector2(ABANDON_COLUMN_WIDTH, 0)
	abandon_button.pressed.connect(_on_abandon_pressed.bind(quest))
	UiStyle.apply_wood_plaque_button(abandon_button, 14.0, 8.0)
	abandon_button.add_theme_font_size_override("font_size", 15)
	return abandon_button


## 資源不夠繳交時 disabled(QuestStore.can_complete_delivery()),避免玩家按下去才發現
## 東西不夠——BaseResourceStore.changed 有接進 _refresh_list()(見 _ready()),存量一有
## 變動這顆按鈕就會跟著重建、反映最新能不能按。
func _build_turn_in_button(quest: Quest) -> Button:
	var turn_in_button := Button.new()
	turn_in_button.text = TURN_IN_BUTTON_LABEL
	turn_in_button.custom_minimum_size = Vector2(TURN_IN_COLUMN_WIDTH, 0)
	turn_in_button.disabled = not QuestStore.can_complete_delivery(quest)
	turn_in_button.pressed.connect(_on_turn_in_pressed.bind(quest))
	UiStyle.apply_wood_plaque_button(turn_in_button, 14.0, 8.0)
	turn_in_button.add_theme_font_size_override("font_size", 15)
	return turn_in_button


## COMPLETED/EXPIRED 都是「已經有結果」的狀態,顏色分開:已完成用金色(達成),
## 已過期用紅色(警示),進行中用綠色。
func _status_color(quest: Quest) -> Color:
	match quest.status:
		GameEnums.QuestStatus.COMPLETED:
			return COMPLETED_COLOR
		GameEnums.QuestStatus.EXPIRED:
			return EXPIRED_COLOR
		_:
			return IN_PROGRESS_COLOR


func _on_abandon_pressed(quest: Quest) -> void:
	QuestStore.abandon_quest(quest)


func _on_turn_in_pressed(quest: Quest) -> void:
	QuestStore.complete_delivery_quest(quest)


func _on_back_pressed() -> void:
	NavigationStore.go_back()
