class_name BarracksPanel
extends VBoxContainer

# =========================================================
# 兵營總覽,嵌在 base_action_panel.gd 的 BaseBuildingPanelContent 裡(寫法比照
# _build_warehouse_section() 直接把內容加進 self,不是另開一層 ActionPanel)。六大項目
# ——傳授/歷練/戰場擴充/戰術格開發/隊長訓練/變換隊形——各自一顆按鈕,點下去整個取代目前
# ActionPanel 內容(ActionPanel.open_custom()),不是原地切換這裡的內容:操作流程統一比照
# base_action_panel.gd 既有的 _open_weapon_craft_panel() 寫法,on_close 一律回
# BaseBuildingEvent.open_action_panel(building),回到這份兵營總覽。
# =========================================================

var _building: Building
var _button_row: HFlowContainer


func setup(building: Building) -> void:
	_building = building


func _ready() -> void:
	add_theme_constant_override("separation", 8)

	# 六顆按鈕排在同一列,擠不下自動換行(HFlowContainer),不用一格按鈕佔一整個 ROW
	# (見 CLAUDE.md 這次需求)。
	_button_row = HFlowContainer.new()
	_button_row.add_theme_constant_override("h_separation", 8)
	_button_row.add_theme_constant_override("v_separation", 8)
	add_child(_button_row)

	_add_button("傳授", _open_teach_panel)
	_add_button("歷練", _open_expedition_panel)
	_add_button("戰場擴充", _open_grid_expand_panel)
	_add_button("戰術格開發", _open_tactical_slot_panel)
	_add_button("隊長訓練", _open_leader_training_panel)
	_add_button("變換隊形", _open_formation_panel)


func _add_button(text: String, on_pressed: Callable) -> void:
	var button := Button.new()
	button.text = text
	UiStyle.style_panel_action_button(button)
	button.pressed.connect(on_pressed)
	_button_row.add_child(button)


func _open_teach_panel() -> void:
	var building := _building
	var panel := BarracksTeachPanel.new()
	ActionPanel.open_custom("兵營－傳授", panel, func(): BaseBuildingEvent.open_action_panel(building))
	panel.setup(building)


func _open_expedition_panel() -> void:
	var building := _building
	var panel := BarracksExpeditionPanel.new(building)
	ActionPanel.open_custom("兵營－歷練", panel, func(): BaseBuildingEvent.open_action_panel(building))


func _open_grid_expand_panel() -> void:
	var building := _building
	var panel := BarracksGridExpandPanel.new()
	ActionPanel.open_custom("兵營－戰場擴充", panel, func(): BaseBuildingEvent.open_action_panel(building))


func _open_tactical_slot_panel() -> void:
	var building := _building
	var content := VBoxContainer.new()
	var label := Label.new()
	label.text = "戰術格開發：功能開發中，敬請期待。"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	content.add_child(label)
	ActionPanel.open_custom("兵營－戰術格開發", content, func(): BaseBuildingEvent.open_action_panel(building))


func _open_leader_training_panel() -> void:
	var building := _building
	var panel := BarracksLeaderTrainingPanel.new()
	ActionPanel.open_custom("兵營－隊長訓練", panel, func(): BaseBuildingEvent.open_action_panel(building))
	panel.setup(building)


func _open_formation_panel() -> void:
	var building := _building
	var panel := BarracksFormationPanel.new()
	ActionPanel.open_custom("兵營－變換隊形", panel, func(): BaseBuildingEvent.open_action_panel(building))
