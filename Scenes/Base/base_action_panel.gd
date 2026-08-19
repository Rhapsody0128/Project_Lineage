class_name BaseActionPanel
extends PanelContainer

## 點擊根據地建築後疊加顯示的行動面板(見 Scenes/Base/base.gd)。所有建築共用「等級/
## 升級」區塊(見 Scripts/Autoload/base_building_progress_store.gd);生產類建築解鎖
## (等級 >0)後顯示目前派遣狀態(容量=等級,見 BaseBuildingProgressStore.get_max_workers()),
## 未滿額可展開角色清單選人派遣,已派遣的每一位都能個別召回;未解鎖的生產類建築只顯示
## 「尚未解鎖」。非生產類建築(城鎮中心/住宅區/醫療所/倉庫/兵營)等級區塊照樣顯示,獨特
## 功能(人口/儲存上限等)顯示「尚未實作」,之後再個別規劃。派遣/召回/查角色一律呼叫
## Scripts/Autoload/base_dispatch_store.gd,升級一律呼叫 BaseBuildingProgressStore,
## 這裡不重複寫規則判斷。

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var body_container: VBoxContainer = $MarginContainer/VBoxContainer/BodyContainer

var _building: Building
## 是否正在展開「選一位角色派遣」清單,關閉面板或派遣/取消後歸零,不跨建築保留。
var _picking_character: bool = false
## 升級失敗(資材不足)後單次顯示一行提示,顯示完就消耗掉,不跨 rebuild 保留。
var _upgrade_error: bool = false


func _ready() -> void:
	# MarginContainer 自己已經有 16px 留白,這裡的 content_margin 只是再多留一點空間
	# 讓文字不要貼在羊皮紙毛邊上,不能沿用大面板(例如 action_panel)的 30/50/30/50——
	# 疊上去會把角色派遣清單(可能好幾顆按鈕,沒有 ScrollContainer)擠到放不下。
	UiStyle.apply_parchment_panel(self, 460.0, 620.0, 16.0, 20.0, 16.0, 20.0)
	title_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)


func open_for_building(building: Building) -> void:
	_building = building
	_picking_character = false
	_upgrade_error = false
	visible = true
	title_label.text = GameEnums.building_type_label(building.type)
	_rebuild_body()


func _rebuild_body() -> void:
	for child in body_container.get_children():
		child.queue_free()

	_build_level_section()

	if not _building.is_production_building():
		_add_label("尚未實作")
		return

	if not BaseBuildingProgressStore.is_unlocked(_building.id):
		_add_label("尚未解鎖,升級後才能派遣角色")
		return

	if _picking_character:
		_build_character_picker()
		return

	_build_dispatch_section()


func _build_level_section() -> void:
	var level := BaseBuildingProgressStore.get_level(_building.id)
	if level > 0:
		_add_label("等級：%s" % GameEnums.rank_label(BaseBuildingProgressStore.get_rank(_building.id)))
	else:
		_add_label("等級：尚未解鎖")

	if BaseBuildingProgressStore.can_upgrade(_building):
		var cost := BaseBuildingProgressStore.get_upgrade_cost(_building)
		var upgrade_button := Button.new()
		upgrade_button.text = "升級至 %s 級（耗材：%s）" % [GameEnums.rank_label(level), _format_cost(cost)]
		upgrade_button.pressed.connect(func() -> void:
			_upgrade_error = not BaseBuildingProgressStore.upgrade(_building)
			_rebuild_body()
		)
		body_container.add_child(upgrade_button)
		if _upgrade_error:
			_add_label("資材不足")
			_upgrade_error = false
	else:
		_add_label("已達最高等級")


func _build_dispatch_section() -> void:
	var max_workers := BaseBuildingProgressStore.get_max_workers(_building.id)
	var dispatched := BaseDispatchStore.get_dispatched_characters(_building.id)
	_add_label("需求素質：%s（容量 %d，已派 %d 位）" % [
		GameEnums.potential_label(_building.potential_type), max_workers, dispatched.size(),
	])

	for character in dispatched:
		var row := HBoxContainer.new()
		var name_label := Label.new()
		name_label.text = character.full_name
		name_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
		row.add_child(name_label)
		var recall_button := Button.new()
		recall_button.text = "召回"
		recall_button.pressed.connect(func() -> void:
			BaseDispatchStore.undispatch(_building.id, character.id)
			_rebuild_body()
		)
		row.add_child(recall_button)
		body_container.add_child(row)

	if dispatched.size() < max_workers:
		var dispatch_button := Button.new()
		dispatch_button.text = "派遣角色"
		dispatch_button.pressed.connect(func() -> void:
			_picking_character = true
			_rebuild_body()
		)
		body_container.add_child(dispatch_button)


func _build_character_picker() -> void:
	var eligible := _get_eligible_characters()
	if eligible.is_empty():
		_add_label("沒有可派遣的角色")
	for character in eligible:
		var button := Button.new()
		var attribute_value := int(character.get_potential(_building.potential_type))
		button.text = "%s（%s：%d）" % [character.full_name, GameEnums.potential_label(_building.potential_type), attribute_value]
		button.pressed.connect(func() -> void:
			var success := BaseDispatchStore.dispatch(_building.id, character.id)
			_picking_character = false
			_rebuild_body()
			if not success:
				_add_label("已滿額")
		)
		body_container.add_child(button)

	var cancel_button := Button.new()
	cancel_button.text = "取消"
	cancel_button.pressed.connect(func() -> void:
		_picking_character = false
		_rebuild_body()
	)
	body_container.add_child(cancel_button)


## 存活且目前沒有派在任何建築的角色才能派遣,見 BaseDispatchStore.is_character_dispatched()。
func _get_eligible_characters() -> Array[Character]:
	var eligible: Array[Character] = []
	for character in CharacterRosterStore.all_characteres:
		if character.is_disabled:
			continue
		if BaseDispatchStore.is_character_dispatched(character.id):
			continue
		eligible.append(character)
	return eligible


func _format_cost(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for resource_type in cost:
		parts.append("%s x%d" % [GameEnums.resource_type_label(resource_type), cost[resource_type]])
	return "、".join(parts)


func _add_label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	body_container.add_child(label)


func _on_close_button_pressed() -> void:
	visible = false
