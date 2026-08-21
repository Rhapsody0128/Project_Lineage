class_name BaseBuildingPanelContent
extends VBoxContainer

## 根據地建築面板的「內容」——不是獨立的彈出面板,外殼(背景遮罩/Margin/離開鈕位置/
## 面板大小)一律共用 Scenes/ActionPanel/action_panel.gd 的 open_custom(),跟酒館招募
## 清單那個彈窗長相一致,只有這塊內容區塊依事件/情況不同換掉(見
## System/event/base/base_building_event.gd 的 _open_action_panel())。
##
## 依 BaseBuildingProgressStore 的狀態分支顯示:0 級未建造顯示「建造」按鈕;建造中顯示
## 倒數天數;已建成顯示等級/升級(升級中不影響下面的產出/派遣顯示,建築正常運作);
## 生產類建築額外顯示目前月產量與工作角色頭像格(容量=等級,點空格開角色清單指派、
## 點已填格子直接召回)。角色清單顯示全部未禁用角色,
## 已在此工作/在別處工作的人反灰純顯示,整卡點擊指派只對可選的人生效,卡片上的頭像
## 另外接一個獨立點擊區開 CharacterPanel(靠子節點 MOUSE_FILTER_STOP 先吃掉事件擋掉
## 冒泡,同 Scenes/Battle/battle_party_roster.gd 頭像框的寫法)。角色清單排成
## PICKER_GRID_COLUMNS 欄的卡片網格,見 _build_character_picker()/_build_character_row()。
##
## 「建造」「升級」鈕不放在這塊內容區塊裡,而是塞進 ActionPanel 自己的標題列
## (ActionPanel.set_title_action_button(),TitleLabel 右邊、CloseButton 左邊),
## 跟名稱/等級同一行,例如「大本營 (F) [升級]」——不用在內容裡重複一次名稱,只要一行。
## title_label.text 也是每次 _rebuild_body() 直接改寫(_build_title_text()),不再另起
## 一行寫「升級至 X 級」。耗材/天數/現有存量不常駐顯示,改成滑鼠移到按鈕上的
## tooltip_text(_build_cost_tooltip(),見 _build_build_button()/_build_upgrade_button());
## 資材不足或城鎮中心等級(effective_max_level)不足都讓按鈕直接 disabled,不用點下去
## 才跳錯誤訊息;建造中/升級中一樣讓按鈕 disabled,tooltip 改顯示倒數天數
## (_build_status_button()),不再另外常駐一行「建造中,X 天後完工」文字——只有已達
## 最高等級這個永久不會再變的狀態不放按鈕(回傳 null),用文字說明。按鈕一律套
## _style_button()(木牌樣式,同 action_panel.gd 清單列的 action_button,
## SIZE_SHRINK_BEGIN 避免被 VBoxContainer 橫向撐滿)。

const AVATAR_SLOT_SIZE := Vector2(64, 64)
const PICKER_FACE_SIZE := Vector2(128, 128)
## 選人清單改成多欄卡片網格(每張卡:大頭像 + 姓名/等級/年紀/適應性素質/潛力評分的
## 兩欄 label:value 小表),不是單一長長一列,充分利用 ActionPanel 的寬度。
const PICKER_GRID_COLUMNS := 3

## 角色清單排序依據——依建築的適應性素質數值/該素質潛力評分/角色等級,
## 由高到低排序(見 _build_sort_dropdown()),方便挑最適合派遣的人。
enum SortMode {STAT, POTENTIAL_RANK, LEVEL}

var _building: Building
## 是否正在展開「選一位角色派遣」清單,指派/取消後歸零。
var _picking_character: bool = false
## 選人清單目前的排序依據,挑人途中(未取消/未指派)維持選擇,重新排序不用重選。
var _sort_mode: SortMode = SortMode.STAT
## 升級/建造失敗(資材不足)後單次顯示一行提示,顯示完就消耗掉,不跨 rebuild 保留。
var _upgrade_error: bool = false
var _build_error: bool = false

## 兵營:是否正在展開「選一位角色受訓」清單;選定角色後改存這裡,接著展開技能清單,
## 兩者互斥(_picking_trainee 只在 _training_character 為 null 時有意義)。
var _picking_trainee: bool = false
var _training_character: Character = null
var _barracks_error: bool = false
## 祭壇/禁忌祭壇購買奧義、科技樹解鎖各自的單次錯誤提示旗標,用法同
## _build_error/_upgrade_error——商隊站/黑市兌換改成每月自動執行,設定當下不會失敗,
## 不需要對應的錯誤旗標。
var _altar_error: bool = false
var _tech_error: bool = false


func _init(p_building: Building) -> void:
	_building = p_building


## 名稱後面直接附等級,例如「住宅區 (F)」——0 級未建造/建造中還沒有等級可顯示,只留
## 名稱。
func _build_title_text() -> String:
	if not BaseBuildingProgressStore.is_unlocked(_building.type):
		return _building.name
	return "%s (%s)" % [_building.name, GameEnums.rank_label(BaseBuildingProgressStore.get_rank(_building.type))]


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	_rebuild_body()


func _rebuild_body() -> void:
	for child in get_children():
		child.queue_free()

	## 名稱/等級跟「建造」「升級」鈕擺在 ActionPanel 標題列同一行(ActionPanel.
	## set_title_action_button()),不在內容區塊裡另外重複一次名稱——ActionPanel 是
	## autoload 單例,這裡直接改寫它目前顯示中的標題列,跟 open_custom() 開面板時傳入
	## 初始標題屬於同一顆 title_label,每次 _rebuild_body() 都會覆寫成最新的名稱/等級。
	ActionPanel.title_label.text = _build_title_text()
	ActionPanel.set_title_action_button(_build_construction_button())
	_add_label(_building.description)

	if _build_error:
		_add_label("資材不足")
		_build_error = false
	if _upgrade_error:
		_add_label("資材不足")
		_upgrade_error = false

	if not BaseBuildingProgressStore.is_unlocked(_building.type):
		return

	var level := BaseBuildingProgressStore.get_level(_building.type)
	if level >= _building.max_level():
		_add_label("已達最高等級")

	if _building.type == GameEnums.BuildingType.BARRACKS:
		_build_barracks_section()
		return

	if _building.type == GameEnums.BuildingType.WAREHOUSE:
		_build_warehouse_section()
		return

	if _building.type == GameEnums.BuildingType.RESIDENTIAL:
		_build_residential_section()
		return

	if not _building.is_production_building():
		return

	if _picking_character:
		_build_character_picker()
		return

	_build_efficiency_label()
	_build_worker_slots()

	match _building.type:
		GameEnums.BuildingType.WORKSHOP:
			_build_recipe_section()
		GameEnums.BuildingType.CARAVAN, GameEnums.BuildingType.BLACK_MARKET:
			_build_exchange_section()
		GameEnums.BuildingType.ALTAR, GameEnums.BuildingType.FORBIDDEN_ALTAR:
			_build_altar_section()
		GameEnums.BuildingType.RESEARCH_INSTITUTE:
			_build_tech_section()


## 已達最高等級是唯一「現在按了也沒用」又不放按鈕的狀態(下面另有文字說明,見
## _rebuild_body())。其餘狀態一律回傳一顆按鈕——資材不足/城鎮中心等級不足/建造中/
## 升級中都不是不顯示按鈕,是讓按鈕 disabled,滑鼠移上去看 tooltip 就知道現在是什麼
## 狀況(進度倒數天數或差在哪),不用另外常駐一行文字。
func _build_construction_button() -> Button:
	if BaseBuildingProgressStore.is_constructing(_building.type):
		return _build_status_button("建造", "建造中,%d 天後完工" % BaseBuildingProgressStore.get_construction_days_remaining(_building.type))
	if not BaseBuildingProgressStore.is_unlocked(_building.type):
		return _build_build_button()
	if BaseBuildingProgressStore.is_upgrading(_building.type):
		return _build_status_button("升級", "升級中,%d 天後完成" % BaseBuildingProgressStore.get_upgrade_days_remaining(_building.type))
	if BaseBuildingProgressStore.get_level(_building.type) >= _building.max_level():
		return null
	return _build_upgrade_button()


## 建造中/升級中專用:按鈕本身 disabled,純粹用 tooltip 顯示進度,不能點。
func _build_status_button(text: String, tooltip: String) -> Button:
	var button := Button.new()
	button.text = text
	_style_button(button)
	button.disabled = true
	button.tooltip_text = tooltip
	return button


func _build_build_button() -> Button:
	var button := Button.new()
	button.text = "建造"
	_style_button(button)

	var level_ok := BaseBuildingProgressStore.effective_max_level(_building) >= 1
	var affordable := BaseResourceStore.can_afford(_building.build_cost)
	button.disabled = not level_ok or not affordable

	var tooltip := _build_cost_tooltip(_building.build_cost, _building.build_days)
	if not level_ok:
		tooltip += "\n市鎮中心等級不足"
	elif not affordable:
		tooltip += "\n資材不足"
	button.tooltip_text = tooltip

	button.pressed.connect(func() -> void:
		_build_error = not BaseBuildingProgressStore.start_construction(_building)
		_rebuild_body()
	)
	return button


## 直接讀 Building.upgrade_costs/upgrade_days(不透過 can_upgrade()/get_upgrade_cost()),
## 因為城鎮中心等級不足時 can_upgrade() 會回傳 false、get_upgrade_cost() 只給空字典——
## 這裡即使升級被城鎮中心等級擋住,也要能算出耗材/天數放進 tooltip 說明「差在哪」,
## 不是直接不顯示按鈕(呼叫端 _build_construction_button() 已保證這裡 level < max_level(),
## upgrade_costs[level - 1] 一定是合法索引)。
func _build_upgrade_button() -> Button:
	var button := Button.new()
	button.text = "升級"
	_style_button(button)

	var level := BaseBuildingProgressStore.get_level(_building.type)
	var cost: Dictionary = _building.upgrade_costs[level - 1]
	var days: int = _building.upgrade_days[level - 1]
	var level_ok := level < BaseBuildingProgressStore.effective_max_level(_building)
	var affordable := BaseResourceStore.can_afford(cost)
	button.disabled = not level_ok or not affordable

	var tooltip := _build_cost_tooltip(cost, days)
	if not level_ok:
		tooltip += "\n市鎮中心等級不足"
	elif not affordable:
		tooltip += "\n資材不足"
	button.tooltip_text = tooltip

	button.pressed.connect(func() -> void:
		_upgrade_error = not BaseBuildingProgressStore.start_upgrade(_building)
		_rebuild_body()
	)
	return button


## 每種資源一行「圖示 現有X / 需要Y」,最後附一行天數,給 _build_build_button()/
## _build_upgrade_button() 的 tooltip_text 用。
func _build_cost_tooltip(cost: Dictionary, days: int) -> String:
	var lines: Array[String] = []
	for resource_type in cost:
		var owned := BaseResourceStore.get_amount(resource_type)
		var required: int = cost[resource_type]
		lines.append("%s 現有%d / 需要%d" % [GameEnums.resource_type_label(resource_type), owned, required])
	lines.append("天數：%d 天" % days)
	return "\n".join(lines)


## 倉庫:列出全部 12 種資源目前的儲存上限(依 System/base/base_warehouse.gd 的
## TIER_BASE/LEVEL_MULTIPLIER 查表),順便附上目前存量,一眼看出哪些資源快頂到上限了。
func _build_warehouse_section() -> void:
	var level := BaseBuildingProgressStore.get_level(_building.type)
	_add_label("目前各資材儲存上限：")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 4)
	for resource_type in GameEnums.ResourceType.values():
		var capacity := BaseWarehouse.get_capacity(resource_type, level)
		var amount := BaseResourceStore.get_amount(resource_type)
		var label := Label.new()
		label.text = "%s %s：%d / %d" % [
			GameEnums.resource_type_label(resource_type), GameEnums.resource_string_label(resource_type), amount, capacity
		]
		label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
		grid.add_child(label)
	add_child(grid)


## 住宅區:人口上限公式(基礎 20 + 住宅每級 +20,見
## Scripts/Autoload/base_building_progress_store.gd 的 get_character_capacity()),
## 順便附上目前實際角色數。
func _build_residential_section() -> void:
	var level := BaseBuildingProgressStore.get_level(_building.type)
	var provided := 20 * level
	var capacity := BaseBuildingProgressStore.get_character_capacity()
	var current := AllCharacterStore.all_characteres.size()
	_add_label("人口上限公式：基礎 20 ＋ 住宅 Lv%d 提供 %d（每級 +20）＝ %d" % [level, provided, capacity])
	_add_label("目前角色數：%d / %d" % [current, capacity])


func _build_efficiency_label() -> void:
	var characters := BaseDispatchStore.get_dispatched_characters(_building.type)
	var level := BaseBuildingProgressStore.get_level(_building.type)
	var monthly_yield := BaseProduction.compute_monthly_yield(_building, characters, level)
	_add_label("目前效率：%d %s/月" % [monthly_yield, GameEnums.resource_type_label(_building.produces)])


func _build_worker_slots() -> void:
	_add_label("工作角色：")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)

	var dispatched := BaseDispatchStore.get_dispatched_characters(_building.type)
	for i in range(BaseBuildingProgressStore.get_max_workers(_building.type)):
		var character: Character = dispatched[i] if i < dispatched.size() else null
		row.add_child(_build_worker_slot(character))


## 已填的格子放頭像,點擊直接召回;空格子點擊展開下方的角色清單(_picking_character)。
func _build_worker_slot(character: Character) -> Control:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = AVATAR_SLOT_SIZE
	slot.add_theme_stylebox_override("panel", UiStyle.parchment_row_style(UiStyle.PARCHMENT_ROW_BORDER, 1, 8, 0.0, 0.0, 0))
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	if character != null:
		var face := TextureRect.new()
		face.custom_minimum_size = AVATAR_SLOT_SIZE
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_SCALE
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not character.face_path.is_empty():
			face.texture = load(character.face_path) as Texture2D
		slot.add_child(face)
		slot.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				BaseDispatchStore.undispatch(_building.type, character.id)
				_rebuild_body()
		)
	else:
		slot.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_picking_character = true
				_rebuild_body()
		)

	return slot


## 顯示全部未禁用角色(不只是可指派的人)——已在此工作/在別處工作的人一樣列出來,
## 靠反灰純視覺區分,召回改到 _build_worker_slot() 那邊點頭像格處理。上面先放排序下拉選單
## (依建築適應性素質/該素質潛力評分/等級,見 _build_sort_dropdown()),一人一列改成
## 表格式緊湊排版(_build_character_list_header() 對齊 _build_character_row() 的欄位)。
func _build_character_picker() -> void:
	var characters: Array[Character] = []
	for character in CharacterRosterStore.all_characteres:
		if not character.is_disabled:
			characters.append(character)

	_build_sort_dropdown()

	if characters.is_empty():
		_add_label("沒有角色")
	else:
		characters.sort_custom(func(a: Character, b: Character) -> bool:
			return _sort_value(a) > _sort_value(b)
		)
		var grid := GridContainer.new()
		grid.columns = PICKER_GRID_COLUMNS
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		add_child(grid)
		for character in characters:
			grid.add_child(_build_character_row(character))

	var cancel_button := Button.new()
	cancel_button.text = "取消"
	_style_button(cancel_button)
	cancel_button.pressed.connect(func() -> void:
		_picking_character = false
		_rebuild_body()
	)
	add_child(cancel_button)


## 排序下拉選單,選項固定 3 種(對應建築的適應性素質),item id 直接用 SortMode 數值,
## 跟 index 剛好一一對應,select()/get_item_id() 不用額外轉換。
func _build_sort_dropdown() -> void:
	var stat_name := GameEnums.potential_label(_building.potential_type)
	var dropdown := OptionButton.new()
	dropdown.add_item("依 %s 排序" % stat_name, SortMode.STAT)
	dropdown.add_item("依 %s 潛力排序" % stat_name, SortMode.POTENTIAL_RANK)
	dropdown.add_item("依等級排序", SortMode.LEVEL)
	dropdown.select(_sort_mode)
	dropdown.item_selected.connect(func(index: int) -> void:
		_sort_mode = dropdown.get_item_id(index) as SortMode
		_rebuild_body()
	)
	add_child(dropdown)


func _sort_value(character: Character) -> float:
	match _sort_mode:
		SortMode.STAT:
			return character.get_potential(_building.potential_type)
		SortMode.POTENTIAL_RANK:
			return character.get_potential_rank(_building.potential_type)
		SortMode.LEVEL:
			return character.level_system.level
		_:
			return 0.0


## 整卡點擊 = 指派(只對可選的人接線,反灰的人點了沒反應);卡片上的頭像另外包一層
## MOUSE_FILTER_STOP + 自己的 gui_input,靠子節點優先吃到輸入事件擋掉往外層卡片冒泡,
## 所有人(含反灰)都能點頭像開 CharacterPanel 看詳情,跟 battle_party_roster.gd 頭像框
## 同一套技巧。卡片右側是姓名/等級/年紀/建築適應性素質/該素質潛力評分的兩欄
## label:value 小表,不再列出全部六維素質——別的素質細節開 CharacterPanel 看,這裡的卡片
## 進 PICKER_GRID_COLUMNS 欄的網格,一次能看到更多角色。
func _build_character_row(character: Character) -> Control:
	var is_here := BaseDispatchStore.get_dispatched_character_ids(_building.type).has(character.id)
	var is_elsewhere := not is_here and BaseDispatchStore.is_character_dispatched(character.id)
	var assignable := not is_here and not is_elsewhere

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiStyle.parchment_row_style(UiStyle.PARCHMENT_ROW_BORDER, 1, 8, 10.0, 6.0))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	if not assignable:
		card.modulate.a = 0.45
		card.tooltip_text = "在此工作" if is_here else "在其他地方工作"
	else:
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				var success := BaseDispatchStore.dispatch(_building.type, character.id)
				_picking_character = false
				_rebuild_body()
				if not success:
					_add_label("已滿額")
		)

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	card.add_child(content)

	var face_wrapper := CenterContainer.new()
	face_wrapper.custom_minimum_size = PICKER_FACE_SIZE
	face_wrapper.mouse_filter = Control.MOUSE_FILTER_STOP
	face_wrapper.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	face_wrapper.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			CharacterPanel.open_for_character(character)
			get_viewport().set_input_as_handled()
	)
	content.add_child(face_wrapper)

	var face := TextureRect.new()
	face.custom_minimum_size = PICKER_FACE_SIZE
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_SCALE
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not character.face_path.is_empty():
		face.texture = load(character.face_path) as Texture2D
	face_wrapper.add_child(face)

	var stat_grid := GridContainer.new()
	stat_grid.columns = 2
	stat_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat_grid.add_theme_constant_override("h_separation", 12)
	stat_grid.add_theme_constant_override("v_separation", 2)
	content.add_child(stat_grid)

	_add_stat_grid_row(stat_grid, "名字", character.full_name)
	_add_stat_grid_row(stat_grid, "等級", str(character.level_system.level))
	_add_stat_grid_row(stat_grid, "年紀", str(character.age))
	_add_stat_grid_row(stat_grid, GameEnums.potential_label(_building.potential_type), str(roundi(character.get_potential(_building.potential_type))))
	_add_stat_grid_row(stat_grid, "潛力", GameEnums.rank_label(character.get_potential_rank(_building.potential_type)))

	return card


func _add_stat_grid_row(stat_grid: GridContainer, label_text: String, value_text: String) -> void:
	var label := Label.new()
	label.text = label_text
	label.add_theme_color_override("font_color", UiStyle.PARCHMENT_SUBTITLE_COLOR)
	stat_grid.add_child(label)

	var value_label := Label.new()
	value_label.text = value_text
	value_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	stat_grid.add_child(value_label)


## 兵營:技能傳授/被動訓練 Rank 上限跟著建築等級開放,不影響戰場 COST(固定 20)。訓練中
## 名單顯示在最上面,底下是「指派角色訓練」入口——依序展開選人清單(_picking_trainee)→
## 選技能清單(_training_character),兩層都能按「取消」退回。
func _build_barracks_section() -> void:
	_add_label("可傳授/訓練最高 Rank：%s" % GameEnums.rank_label(BaseBuildingProgressStore.get_rank(_building.type)))
	_add_label("戰場 COST 固定 20，不受兵營等級影響。")

	var trainees := BarracksTrainingStore.get_trainees()
	if not trainees.is_empty():
		_add_label("訓練中：")
		for character_id in trainees:
			var character := BaseDispatchStore.find_character(character_id)
			if character == null:
				continue
			var skill := BarracksTrainingStore.get_skill(character_id)
			_add_label("%s 學習「%s」，%d 天後完成" % [
				character.full_name, skill.name, BarracksTrainingStore.get_days_remaining(character_id)
			])

	if _training_character != null:
		_build_skill_picker()
		return

	if _picking_trainee:
		_build_trainee_picker()
		return

	var button := Button.new()
	button.text = "指派角色訓練"
	_style_button(button)
	button.pressed.connect(func() -> void:
		_picking_trainee = true
		_rebuild_body()
	)
	add_child(button)


## 只列出目前空閒(未受訓/未派駐其他建築)的未禁用角色——不比照生產建築的派遣清單顯示
## 全部角色反灰,訓練是相對少發生的操作,直接濾掉不可選的人更清楚。
func _build_trainee_picker() -> void:
	var characters: Array[Character] = []
	for character in CharacterRosterStore.all_characteres:
		if not character.is_disabled and not BarracksTrainingStore.is_training(character.id) and not BaseDispatchStore.is_character_dispatched(character.id):
			characters.append(character)

	if characters.is_empty():
		_add_label("沒有可派遣的角色")
	else:
		for character in characters:
			add_child(_build_trainee_row(character))

	var cancel_button := Button.new()
	cancel_button.text = "取消"
	_style_button(cancel_button)
	cancel_button.pressed.connect(func() -> void:
		_picking_trainee = false
		_rebuild_body()
	)
	add_child(cancel_button)


func _build_trainee_row(character: Character) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var label := Label.new()
	label.text = "%s（%d 歲）" % [character.full_name, character.age]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	row.add_child(label)

	var button := Button.new()
	button.text = "選擇"
	_style_button(button)
	button.pressed.connect(func() -> void:
		_training_character = character
		_picking_trainee = false
		_rebuild_body()
	)
	row.add_child(button)

	return row


## 技能池取自 SkillLibrary.build()(主動/被動不分,方案 A:傳授新技能與訓練被動技能
## 共用同一套規則),過濾條件只有兩個:Rank ≤ 兵營等級、角色還不會這個技能。
func _build_skill_picker() -> void:
	_add_label("為 %s 選擇要學習的技能：" % _training_character.full_name)

	var rank_cap := BaseBuildingProgressStore.get_rank(_building.type)
	var eligible: Array[Skill] = []
	for skill in SkillLibrary.build():
		if skill.rank <= rank_cap and not BarracksTraining.character_knows_skill(_training_character, skill):
			eligible.append(skill)

	if eligible.is_empty():
		_add_label("沒有可學習的新技能")
	else:
		for skill in eligible:
			add_child(_build_skill_row(skill))

	if _barracks_error:
		_add_label("資材不足")
		_barracks_error = false

	var cancel_button := Button.new()
	cancel_button.text = "取消"
	_style_button(cancel_button)
	cancel_button.pressed.connect(func() -> void:
		_training_character = null
		_rebuild_body()
	)
	add_child(cancel_button)


func _build_skill_row(skill: Skill) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var days := BarracksTraining.days_for_rank(skill.rank)
	var cost := BarracksTraining.cost_for_rank(skill.rank)
	var label := Label.new()
	label.text = "%s（%s，耗材：%s，天數：%d 天）" % [skill.name, GameEnums.rank_label(skill.rank), _format_cost(cost), days]
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	row.add_child(label)

	var button := Button.new()
	button.text = "開始訓練"
	_style_button(button)
	var character := _training_character
	button.pressed.connect(func() -> void:
		if BarracksTrainingStore.start_training(character, skill):
			_training_character = null
			_rebuild_body()
		else:
			_barracks_error = true
			_rebuild_body()
	)
	row.add_child(button)

	return row


## 工匠坊:五種配方任選一種,月結算時依 WorkshopRecipeStore 目前選定的配方換算實際產出
## (見 Scripts/Autoload/base_dispatch_store.gd 的 _resolve_workshop_yield())。原料不夠時
## 整個月不生產、不消耗(不是部分打折),選中的配方下面直接列出本月預計消耗/取得量,
## 讓玩家換配方前先看得到會不會白忙一場。沒派工作角色時是另一回事(沒人做事,不是原料
## 不足),分開判斷、分開顯示,見 _build_recipe_row() 的 has_workers。
func _build_recipe_section() -> void:
	_add_label("配方（資源不足時整個月不生產）：")
	var selected_id := WorkshopRecipeStore.get_selected().id
	var characters := BaseDispatchStore.get_dispatched_characters(_building.type)
	var level := BaseBuildingProgressStore.get_level(_building.type)
	var theoretical_output := BaseProduction.compute_monthly_yield(_building, characters, level)
	var has_workers := not characters.is_empty()
	for recipe in WorkshopRecipeLibrary.get_all():
		add_child(_build_recipe_row(recipe, recipe.id == selected_id, theoretical_output, has_workers))


## 未選用的配方只列品項名稱,消耗/產出(或原料不足)這些細節選用後才在同一塊空間往下
## 多一行顯示,不用每種配方都攤開一次資訊——「製作工藝」這個資源改用 emoji
## (GameEnums.resource_type_label)呈現,不寫死中文字。
func _build_recipe_row(recipe: WorkshopRecipe, is_selected: bool, theoretical_output: int, has_workers: bool) -> Control:
	var column := VBoxContainer.new()

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)

	var label := Label.new()
	label.text = recipe.name
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	row.add_child(label)

	var button := Button.new()
	button.text = "使用中" if is_selected else "選用"
	button.disabled = is_selected
	_style_button(button)
	button.pressed.connect(func() -> void:
		WorkshopRecipeStore.select(recipe.id)
		_rebuild_body()
	)
	row.add_child(button)

	if is_selected:
		var craft_icon := GameEnums.resource_type_label(GameEnums.ResourceType.CRAFT)
		var preview_label := Label.new()
		preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		preview_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_SUBTITLE_COLOR)
		if recipe.inputs.is_empty():
			preview_label.text = "本月不消耗原料,也不會產出"
		elif not has_workers:
			preview_label.text = "尚未指派工作角色,本月不會生產"
		else:
			var available: Dictionary = {}
			for resource_type in recipe.inputs:
				available[resource_type] = BaseResourceStore.get_amount(resource_type)
			var result := WorkshopProduction.resolve(recipe, theoretical_output, available)
			if result.output <= 0:
				preview_label.text = "本月原料不足,將不會生產"
			else:
				preview_label.text = "本月將消耗 %s，取得 %d %s" % [_format_cost(result.consumed), result.output, craft_icon]
		column.add_child(preview_label)

	return column


## 商隊站/黑市:被動生產(AGI→金錢/贓物)維持不變,這裡是疊加上去的「每月自動兌換」——
## 玩家設定方向(買入/賣出)/資源/數量(拉桿),每月結算時自動執行一次;資源不夠時整個月
## 不換(不會部分兌換、不會扣成負數),沒有另外的每月額度上限。拉桿拖曳中只更新預覽
## 文字跟即時寫回 BaseExchangeStore,不整包 _rebuild_body(),避免拖曳被打斷。
func _build_exchange_section() -> void:
	var building_type := _building.type
	var currency := BaseExchange.currency_for(building_type)
	var options := BaseExchange.options_for(building_type)
	var order := BaseExchangeStore.get_order(building_type)

	_add_label("每月自動兌換（資源不夠時該月不換,不會扣成負數,沒有每月額度上限）：")

	var direction_group := ButtonGroup.new()
	var direction_row := HBoxContainer.new()
	direction_row.add_theme_constant_override("separation", 8)
	add_child(direction_row)

	var buy_button := Button.new()
	buy_button.text = "買入（%s → 資材）" % GameEnums.resource_type_label(currency)
	buy_button.toggle_mode = true
	buy_button.button_group = direction_group
	buy_button.button_pressed = order.get("is_buy", true)
	_style_button(buy_button)
	direction_row.add_child(buy_button)

	var sell_button := Button.new()
	sell_button.text = "賣出（資材 → %s）" % GameEnums.resource_type_label(currency)
	sell_button.toggle_mode = true
	sell_button.button_group = direction_group
	sell_button.button_pressed = not order.get("is_buy", true)
	_style_button(sell_button)
	direction_row.add_child(sell_button)

	var resource_dropdown := OptionButton.new()
	for option in options:
		resource_dropdown.add_item(GameEnums.resource_type_label(option.resource), option.resource)
	var selected_resource: int = order.get("resource", -1)
	if selected_resource == -1 and not options.is_empty():
		selected_resource = options[0].resource
	for i in range(resource_dropdown.item_count):
		if resource_dropdown.get_item_id(i) == selected_resource:
			resource_dropdown.select(i)
	add_child(resource_dropdown)

	var slider_row := HBoxContainer.new()
	slider_row.add_theme_constant_override("separation", 8)
	add_child(slider_row)

	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 200
	slider.step = 1
	slider.value = order.get("units", 0)
	slider.custom_minimum_size = Vector2(320, 0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider_row.add_child(slider)

	var units_label := Label.new()
	units_label.custom_minimum_size = Vector2(60, 0)
	units_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	slider_row.add_child(units_label)

	var preview_label := Label.new()
	preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	preview_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_SUBTITLE_COLOR)
	add_child(preview_label)

	var refresh_preview := func() -> void:
		var is_buy := buy_button.button_pressed
		var resource := resource_dropdown.get_selected_id()
		var units := int(slider.value)
		units_label.text = "x%d" % units
		BaseExchangeStore.set_order(building_type, is_buy, resource, units)
		var result := BaseExchangeStore.preview(building_type)
		if result.source_amount <= 0:
			preview_label.text = "尚未設定兌換數量"
		else:
			preview_label.text = "本月將消耗 %d %s，取得 %d %s" % [
				result.source_amount, GameEnums.resource_type_label(result.source_resource),
				result.target_amount, GameEnums.resource_type_label(result.target_resource)
			]

	buy_button.toggled.connect(func(_pressed: bool) -> void: refresh_preview.call())
	sell_button.toggled.connect(func(_pressed: bool) -> void: refresh_preview.call())
	resource_dropdown.item_selected.connect(func(_index: int) -> void: refresh_preview.call())
	slider.value_changed.connect(func(_value: float) -> void: refresh_preview.call())

	refresh_preview.call()


## 祭壇/禁忌祭壇:購買奧義直接對接既有 UltimateStore 的次數系統,消耗資源用
## _building.produces(祭壇=信仰、禁忌祭壇=詛咒),不用另外分流。畫面分兩段:上面
## 「目前擁有的奧義」是唯讀的次數總覽(獨立於下面的購買列,不用在每次點購買前先找到
## 「目前剩餘 X 次」那行字),下面「可購買」每顆按鈕按一下就是買一次,沒有數量選擇;
## 兩段都把長版效果說明改成滑鼠移過去的 tooltip(tooltip_text),不佔版面。
func _build_altar_section() -> void:
	var rank_cap := BaseBuildingProgressStore.get_rank(_building.type)
	var ultimates := (
		UltimateLibrary.self_ultimates() if _building.type == GameEnums.BuildingType.ALTAR
		else UltimateLibrary.enemy_ultimates()
	)

	_add_label("目前已擁有的奧義：")
	for ultimate in ultimates:
		add_child(_build_owned_ultimate_label(ultimate))

	_add_label("可兌換奧義：")

	var eligible: Array[Ultimate] = []
	for ultimate in ultimates:
		if ultimate.rank <= rank_cap:
			eligible.append(ultimate)

	if eligible.is_empty():
		_add_label("建築等級不足,尚無可購買的奧義")
	else:
		for ultimate in eligible:
			add_child(_build_ultimate_row(ultimate))

	if _altar_error:
		_add_label("資源不足")
		_altar_error = false


func _build_owned_ultimate_label(ultimate: Ultimate) -> Control:
	var label := Label.new()
	label.text = "%s（%s）：剩餘 %d 次" % [
		ultimate.name, GameEnums.rank_label(ultimate.rank), UltimateStore.uses_remaining(ultimate)
	]
	label.tooltip_text = ultimate.description
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	return label


func _build_ultimate_row(ultimate: Ultimate) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var cost := BaseAltar.cost_for_rank(ultimate.rank)
	var label := Label.new()
	label.text = "%s (%s) ：消耗 %s %s" % [ultimate.name, GameEnums.rank_label(ultimate.rank), GameEnums.resource_type_label(_building.produces), cost]
	label.tooltip_text = ultimate.description
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	row.add_child(label)

	var button := Button.new()
	button.text = "購買"
	_style_button(button)
	var resource_type := _building.produces
	button.pressed.connect(func() -> void:
		if BaseResourceStore.can_afford({resource_type: cost}):
			BaseResourceStore.spend({resource_type: cost})
			UltimateStore.add_uses(ultimate, 1)
			_rebuild_body()
		else:
			_altar_error = true
			_rebuild_body()
	)
	row.add_child(button)

	return row


## 科學研究所:15 格科技樹,依分類分組顯示,門檻/科研消耗見 TechLibrary。效果本身
## (升級耗材-10%、移動速度+10%等)目前只追蹤解鎖狀態,尚未接上實際加成邏輯。
func _build_tech_section() -> void:
	_add_label("科技樹（花科研永久解鎖,依科學研究所等級解鎖對應門檻）：")
	var level := BaseBuildingProgressStore.get_level(_building.type)

	var by_category: Dictionary = {}
	for tech in TechLibrary.get_all():
		var list: Array = by_category.get(tech.category, [])
		list.append(tech)
		by_category[tech.category] = list

	for category in by_category:
		_add_label(category)
		for tech in by_category[category]:
			add_child(_build_tech_row(tech, level))

	if _tech_error:
		_add_label("門檻不足或科研不足")
		_tech_error = false


func _build_tech_row(tech: Tech, research_institute_level: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var unlocked := TechStore.is_unlocked(tech.id)
	var meets_level := research_institute_level >= TechLibrary.level_requirement(tech.tier)
	var label := Label.new()
	label.text = "%s：%s（科研 %d，需研究所 %s 級）" % [
		tech.name, tech.description, tech.cost, GameEnums.rank_label(TechLibrary.level_requirement(tech.tier) - 1)
	]
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	row.add_child(label)

	var button := Button.new()
	if unlocked:
		button.text = "已解鎖"
		button.disabled = true
	elif not meets_level:
		button.text = "等級不足"
		button.disabled = true
	else:
		button.text = "解鎖"
		button.pressed.connect(func() -> void:
			_tech_error = not TechStore.unlock(tech)
			_rebuild_body()
		)
	_style_button(button)
	row.add_child(button)

	return row


func _format_cost(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for resource_type in cost:
		parts.append("%s x%d" % [GameEnums.resource_type_label(resource_type), cost[resource_type]])
	return "、".join(parts)


## 「按鈕都用 ACTION PANEL WOOD PANEL」——比照 Scenes/ActionPanel/action_panel.gd 清單列
## 的 action_button 那套木牌樣式(UiStyle.apply_wood_plaque_button()),讓根據地建築面板
## 內的按鈕跟其他彈出面板長相一致,不再是預設灰底按鈕。SIZE_SHRINK_BEGIN 是關鍵——這個
## VBoxContainer 對子節點的橫向(交叉軸)預設會撐滿整個面板寬度,直接 add_child(button)
## 的按鈕(建造/升級/取消等)不設這個的話,木牌貼圖會被硬拉成一整條很長的長方形,不是
## 圖片原本的比例;設成 SHRINK_BEGIN 後按鈕只會跟內容(文字+邊距)一樣寬,靠左對齊。
func _style_button(button: Button) -> void:
	UiStyle.apply_wood_plaque_button(button, 16.0, 6.0)
	button.add_theme_font_size_override("font_size", 16)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN


func _add_label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	add_child(label)
