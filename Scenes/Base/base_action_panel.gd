class_name BaseActionPanel
extends PanelContainer

## 點擊根據地建築後疊加顯示的行動面板(見 Scenes/Base/base.gd)。非生產類建築(城鎮
## 中心/住宅區/醫療所/倉庫/兵營)顯示「尚未實作」;生產類建築顯示目前派遣狀態,
## 未派遣時可展開角色清單選人派遣,已派遣時可召回。派遣/召回/查角色一律呼叫
## Scripts/Autoload/base_dispatch_store.gd,這裡不重複寫規則判斷。

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var body_container: VBoxContainer = $MarginContainer/VBoxContainer/BodyContainer

var _building: Building
## 是否正在展開「選一位角色派遣」清單,關閉面板或派遣/取消後歸零,不跨建築保留。
var _picking_character: bool = false


func _ready() -> void:
	# MarginContainer 自己已經有 16px 留白,這裡的 content_margin 只是再多留一點空間
	# 讓文字不要貼在羊皮紙毛邊上,不能沿用大面板(例如 action_panel)的 30/50/30/50——
	# 疊上去會把角色派遣清單(可能好幾顆按鈕,沒有 ScrollContainer)擠到放不下。
	UiStyle.apply_parchment_panel(self, 460.0, 620.0, 16.0, 20.0, 16.0, 20.0)
	title_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)


func open_for_building(building: Building) -> void:
	_building = building
	_picking_character = false
	visible = true
	title_label.text = GameEnums.building_type_label(building.type)
	_rebuild_body()


func _rebuild_body() -> void:
	for child in body_container.get_children():
		child.queue_free()

	if not _building.is_production_building():
		_add_label("尚未實作")
		return

	if _picking_character:
		_build_character_picker()
		return

	var dispatched_character := BaseDispatchStore.get_dispatched_character(_building.id)
	if dispatched_character != null:
		_add_label("派遣中：%s" % dispatched_character.full_name)
		var recall_button := Button.new()
		recall_button.text = "召回"
		recall_button.pressed.connect(func() -> void:
			BaseDispatchStore.undispatch(_building.id)
			_rebuild_body()
		)
		body_container.add_child(recall_button)
	else:
		_add_label("需求素質：%s" % GameEnums.potential_label(_building.potential_type))
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
			BaseDispatchStore.dispatch(_building.id, character.id)
			_picking_character = false
			_rebuild_body()
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


func _add_label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	body_container.add_child(label)


func _on_close_button_pressed() -> void:
	visible = false
