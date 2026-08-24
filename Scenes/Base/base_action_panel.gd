class_name BaseBuildingPanelContent
extends VBoxContainer

## 根據地建築面板的「內容」——不是獨立的彈出面板,外殼(背景遮罩/Margin/離開鈕位置/
## 面板大小)一律共用 Scenes/ActionPanel/action_panel.gd 的 open_custom(),跟酒館招募
## 清單那個彈窗長相一致,只有這塊內容區塊依事件/情況不同換掉(見
## System/event/base/base_building_event.gd 的 _open_action_panel())。
##
## 依 BaseBuildingProgressStore 的狀態分支顯示:0 級未建造顯示「建造」按鈕;建造中顯示
## 倒數天數;已建成顯示等級/升級(升級中不影響下面的產出/派遣顯示,建築正常運作);
## 生產類建築額外顯示目前月產量與工作角色頭像格(容量=等級,點空格開角色選人面板指派、
## 點已填格子直接召回)。
##
## 「選一位角色」情境(派遣工作角色/兵營指派受訓/更換整團領導人)一律呼叫
## Scenes/CharacterSelect/character_select_overlay.gd 的 CharacterSelectOverlay,疊加在
## 這份建築面板最上層(獨立 CanvasLayer,不是原地替換 ActionPanel 目前的內容)——self
## 全程留在畫面上不受影響,選定/取消都只是把疊加面板關掉,接下來直接沿用 self 更新狀態、
## 呼叫 _rebuild_body(),見 _open_dispatch_picker()/_open_trainee_picker()/
## _open_leader_picker() 的既有寫法。城鎮中心聯姻是例外:選聯姻角色/寄信國家改走
## Scenes/Marriage/stronghold_marriage_panel.gd 的 StrongholdMarriagePanel(見
## _open_stronghold_marriage_panel()),外殼直接換掉 ActionPanel 目前顯示的內容(不是疊
## 加),候選人盲選跟後續 Dialogue 演出則交給 System/event/base/base_marriage_event.gd。
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

var _building: Building
## 升級/建造/派遣失敗後單次顯示一行提示,顯示完就消耗掉,不跨 rebuild 保留。
var _upgrade_error: bool = false
var _build_error: bool = false
var _dispatch_error: bool = false

## 兵營:選定要受訓的角色後存這裡,接著展開技能清單(_build_skill_picker())。
var _training_character: Character = null
var _barracks_error: bool = false
## 祭壇/禁忌祭壇購買奧義、科技樹解鎖各自的單次錯誤提示旗標,用法同
## _build_error/_upgrade_error——商隊站/黑市兌換改成每月自動執行,設定當下不會失敗,
## 不需要對應的錯誤旗標。
var _altar_error: bool = false
var _tech_error: bool = false

## 城鎮中心:聯姻結果單次顯示,顯示完即消耗掉,同 _build_error/_upgrade_error 慣例。實際
## 選聯姻角色/寄信國家兩步驟已經整個交給 Scenes/Marriage/stronghold_marriage_panel.gd 的
## StrongholdMarriagePanel(見 _open_stronghold_marriage_panel()),候選人盲選跟後續
## Dialogue 演出則在 System/event/base/base_marriage_event.gd,這裡不再需要自己存流程
## 中途狀態。
var _marriage_result_text: String = ""


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
	ActionPanel.set_title_action_button(_build_title_action_row())
	_add_label(_building.description)

	if _build_error:
		_add_label("資材不足")
		_build_error = false
	if _upgrade_error:
		_add_label("資材不足")
		_upgrade_error = false
	if _dispatch_error:
		_add_label("已滿額")
		_dispatch_error = false

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

	if _building.type == GameEnums.BuildingType.STRONGHOLD:
		_build_stronghold_section()
		return

	if not _building.is_production_building():
		return

	_build_efficiency_label()
	_build_worker_slots()

	if _building.fixed_recipe != null:
		_build_fixed_recipe_section()

	match _building.type:
		GameEnums.BuildingType.WORKSHOP:
			_build_recipe_section()
		GameEnums.BuildingType.CARAVAN, GameEnums.BuildingType.BLACK_MARKET:
			_build_exchange_section()
		GameEnums.BuildingType.ALTAR, GameEnums.BuildingType.FORBIDDEN_ALTAR:
			_build_altar_section()
		GameEnums.BuildingType.RESEARCH_INSTITUTE:
			_build_tech_section()


## 生產類建築已解鎖時,在建造/升級鈕左邊多插一顆啟動/暫停開關鈕(見
## _build_active_toggle_button()),包成 HBoxContainer 一起塞進 ActionPanel 標題列;
## 其餘情況(非生產建築、或建築還沒解鎖)直接回傳 _build_construction_button() 本身
## (可能是 null,例如已達最高等級)。
func _build_title_action_row() -> Control:
	var construction_button := _build_construction_button()
	if not _building.is_production_building() or not BaseBuildingProgressStore.is_unlocked(_building.type):
		return construction_button

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(_build_active_toggle_button())
	if construction_button != null:
		row.add_child(construction_button)
	return row


## 關閉後 BaseDispatchStore 月結算整棟跳過(不產出、不消耗、角色也不會拿到派遣經驗,
## 見 Scripts/Autoload/base_dispatch_store.gd),預設啟動。
func _build_active_toggle_button() -> Button:
	var button := Button.new()
	button.toggle_mode = true
	var active := BaseBuildingProgressStore.is_active(_building.type)
	button.text = "運作中" if active else "已暫停"
	button.button_pressed = active
	_style_button(button)
	button.pressed.connect(func() -> void:
		BaseBuildingProgressStore.set_active(_building.type, not BaseBuildingProgressStore.is_active(_building.type))
		_rebuild_body()
	)
	return button


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
	var button := CostTooltipButton.new()
	button.text = "建造"
	_style_button(button)

	var level_ok := BaseBuildingProgressStore.effective_max_level(_building) >= 1
	var affordable := BaseResourceStore.can_afford(_building.build_cost)
	button.disabled = not level_ok or not affordable

	var extra_lines: Array[String] = []
	if not level_ok:
		extra_lines.append("市鎮中心等級不足")
	elif not affordable:
		extra_lines.append("資材不足")
	button.set_cost_tooltip(_building.build_cost, _building.build_days, extra_lines)
	button.tooltip_text = _build_cost_tooltip(_building.build_cost, _building.build_days, extra_lines)

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
	var button := CostTooltipButton.new()
	button.text = "升級"
	_style_button(button)

	var level := BaseBuildingProgressStore.get_level(_building.type)
	var cost: Dictionary = _building.upgrade_costs[level - 1]
	var days: int = _building.upgrade_days[level - 1]
	var level_ok := level < BaseBuildingProgressStore.effective_max_level(_building)
	var affordable := BaseResourceStore.can_afford(cost)
	button.disabled = not level_ok or not affordable

	var extra_lines: Array[String] = []
	if not level_ok:
		extra_lines.append("市鎮中心等級不足")
	elif not affordable:
		extra_lines.append("資材不足")
	button.set_cost_tooltip(cost, days, extra_lines)
	button.tooltip_text = _build_cost_tooltip(cost, days, extra_lines)

	button.pressed.connect(func() -> void:
		_upgrade_error = not BaseBuildingProgressStore.start_upgrade(_building)
		_rebuild_body()
	)
	return button


## 每種資源一行「現有X / 需要Y」,最後附一行天數,純文字備援(見
## Scenes/Base/cost_tooltip_button.gd 開頭註解)——真正顯示給玩家看的是
## CostTooltipButton._make_custom_tooltip() 組的圖示版本。
func _build_cost_tooltip(cost: Dictionary, days: int, extra_lines: Array[String] = []) -> String:
	var lines: Array[String] = []
	for resource_type in cost:
		var owned := BaseResourceStore.get_amount(resource_type)
		var required: int = cost[resource_type]
		lines.append("%s 現有%d / 需要%d" % [GameEnums.resource_string_label(resource_type), owned, required])
	lines.append("天數：%d 天" % days)
	lines.append_array(extra_lines)
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
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		row.add_child(_build_resource_icon(resource_type))
		var label := Label.new()
		var capacity_text := "∞" if capacity < 0 else str(capacity)
		label.text = "%s：%d / %s" % [GameEnums.resource_string_label(resource_type), amount, capacity_text]
		label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
		row.add_child(label)
		grid.add_child(row)
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


## 城鎮中心:聯姻入口。名額公式見 MarriageQuotaRule.max_quota_per_year()(城鎮中心每級
## +1 個名額),用掉幾個名額是 MarriageQuotaStore 的玩家資料,跨年自動歸零、升級不會
## 把已用掉的名額補回來(見該檔案開頭註解)。名額剩餘/不能聯姻的原因不再常駐一行文字,
## 改寫進「聯姻」按鈕的 tooltip(_build_marriage_button()),按下去才展開整段選人流程,
## 選聯姻角色/寄信國家兩步驟已經整個交給 Scenes/Marriage/stronghold_marriage_panel.gd 的
## StrongholdMarriagePanel,這裡不再自己存流程中途狀態。
func _build_stronghold_section() -> void:
	_build_leader_change_section()

	if not _marriage_result_text.is_empty():
		_add_label(_marriage_result_text)
		_marriage_result_text = ""

	add_child(_build_marriage_button())


## 名額剩餘/不能聯姻的原因(名額用完、沒有可聯姻的角色)一律寫進 tooltip,按鈕本身只留
## 「聯姻」兩個字——不用玩家先看到一行常駐文字才知道能不能按,滑鼠移上去就有完整說明。
func _build_marriage_button() -> Button:
	var button := Button.new()
	button.text = "聯姻"
	_style_button(button)

	var remaining := MarriageQuotaStore.remaining()
	var eligible := MarriageRule.eligible_proposers(CharacterRosterStore.all_characteres)
	var tooltip_lines: Array[String] = ["本年度聯姻名額剩餘：%d（城鎮中心每級 +1 個,跨年重新計算）" % remaining]
	if remaining <= 0:
		tooltip_lines.append("本年度名額已用完")
	if eligible.is_empty():
		tooltip_lines.append("沒有可聯姻的角色（角色皆已婚或被禁用）")
	button.tooltip_text = "\n".join(tooltip_lines)
	button.disabled = remaining <= 0 or eligible.is_empty()

	button.pressed.connect(func() -> void: _open_stronghold_marriage_panel(eligible))
	return button


## 城鎮中心:更換整團領導人入口。跟下面小隊隊長(Party.leader,只在戰場站位/金色標記/
## 隊長陣亡判斷用)是完全不同的兩件事(見 Scripts/Autoload/leader_store.gd 開頭
## 註解)——整團領導人代表玩家在大地圖各對話事件(TownGateEvent/TownChatEvent/
## RoamingEnemyEvent/BaseMarriageEvent 等)開口說話,不需要人在目前小隊裡也能被指定,
## 選人範圍是全部角色池(CharacterRosterStore.all_characteres),按鈕只要角色池不是空的
## 就能按——一定至少有主角,實務上不會發生沒人可選的狀況,但仍防呆。
func _build_leader_change_section() -> void:
	_add_label("目前整團領導人：%s" % LeaderStore.get_leader().full_name)

	var button := Button.new()
	button.text = "更換領導人"
	_style_button(button)
	button.disabled = CharacterRosterStore.all_characteres.is_empty()
	button.pressed.connect(func() -> void: _open_leader_picker())
	add_child(button)


## 選定範圍是全部角色池,不限定要編入目前小隊——跟 _open_dispatch_picker() 派遣工作角色
## 同一套慣例(顯示全部未禁用角色)。initial_focus 帶目前領導人,一開進來就先聚焦顯示,
## 不用玩家先點一次才看得到資料。
func _open_leader_picker() -> void:
	var characters: Array[Character] = []
	for character in CharacterRosterStore.all_characteres:
		if not character.is_disabled:
			characters.append(character)

	var overlay := CharacterSelectOverlay.new()
	get_tree().root.add_child(overlay)
	overlay.open_picker(
		"選擇整團領導人", characters, _simple_avatar_card, -1,
		_on_leader_confirmed, "設為領導人", LeaderStore.get_leader()
	)


func _on_leader_confirmed(character: Character) -> void:
	LeaderStore.set_leader(character)
	_rebuild_body()


## 「聯姻」按鈕按下後呼叫:選聯姻角色→選寄信國家兩步驟,整個交給
## Scenes/Marriage/stronghold_marriage_panel.gd 的 StrongholdMarriagePanel 一份 ActionPanel
## 內容處理——直接換掉 ActionPanel 目前顯示的城鎮中心建築面板內容(不是疊加),self(這份
## 建築面板內容)因此會被 ActionPanel.open_custom() 釋放掉,跟
## _open_dispatch_picker()/_open_trainee_picker()/_open_leader_picker() 三個
## CharacterSelectOverlay 選人情境(疊加在最上層,self 全程不受影響)是不同的模式。取消/×
## 時 on_close 重新呼叫 BaseBuildingEvent.open_action_panel() 開一份全新的建築面板(比照
## BaseMarriageEvent._finish() 演出結束後回到城鎮中心面板的既有寫法),不嘗試復用已經被釋放
## 的這份 self。self 即將被釋放,下面兩個 lambda 因此不能再透過隱含的 self 存取
## `_building`,改成先存進區域變數 building 再捕捉——lambda 執行的當下(玩家真正按下
## 取消/確認聯姻)self 早就不在了。確認聯姻時面板自己呼叫 setup() 傳入的 on_confirmed,
## 這裡收到後只需要 ActionPanel.close(false) 讓路、接手交給 BaseMarriageEvent 演出後續
## Dialogue/候選人盲選。
func _open_stronghold_marriage_panel(eligible: Array[Character]) -> void:
	var building := _building
	var panel := StrongholdMarriagePanel.new()
	ActionPanel.open_custom("城鎮中心聯姻", panel, func(): BaseBuildingEvent.open_action_panel(building))
	panel.setup(eligible, func(proposer: Character, nation: int) -> void:
		# BaseMarriageEvent 接下來會呼叫 goto_dialogue() 真的切場景離開 base.tscn——
		# ActionPanel 掛在 autoload CanvasLayer 上不會跟著切場景消失,要先手動關掉,不然會
		# 一路疊在 Dialogue 畫面最上層(理由同 BaseMarriageEvent 內部各處 ActionPanel.close()
		# 呼叫點的既有註解)。trigger_callback=false,避免又觸發上面那個重開建築面板的
		# on_close。
		ActionPanel.close(false)
		BaseMarriageEvent.trigger(building, proposer, nation)
	)


func _build_efficiency_label() -> void:
	var characters := BaseDispatchStore.get_dispatched_characters(_building.type)
	var level := BaseBuildingProgressStore.get_level(_building.type)
	var monthly_yield := BaseProduction.compute_monthly_yield(_building, characters, level)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.add_child(_build_plain_text("目前效率：%d" % monthly_yield))
	row.add_child(_build_resource_icon(_building.produces))
	row.add_child(_build_plain_text("/月"))
	add_child(row)


func _build_plain_text(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	return label


func _build_worker_slots() -> void:
	_add_label("工作角色：")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)

	var dispatched := BaseDispatchStore.get_dispatched_characters(_building.type)
	for i in range(BaseBuildingProgressStore.get_max_workers(_building.type)):
		var character: Character = dispatched[i] if i < dispatched.size() else null
		row.add_child(_build_worker_slot(character))


## 已填的格子放頭像,點擊直接召回;空格子點擊疊出選人面板(_open_dispatch_picker())。
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
				_open_dispatch_picker()
		)

	return slot


## 顯示全部未禁用角色(不只是可指派的人)——已在此工作/在別處工作的人一樣列出來,
## 靠 CharacterAvatarCard 的 available/unavailable_reason 反灰純視覺區分,召回維持在
## _build_worker_slot() 點頭像格處理。排序預設依建築適應性素質(見 CharacterSelectBar.
## setup() 的 initial_sort_key,3 + PotentialType 剛好對應 GameEnums.CharacterSortKey 的
## STRENGTH..MENTALITY,見該檔案註解)。
func _open_dispatch_picker() -> void:
	var characters: Array[Character] = []
	for character in CharacterRosterStore.all_characteres:
		if not character.is_disabled:
			characters.append(character)

	var overlay := CharacterSelectOverlay.new()
	get_tree().root.add_child(overlay)
	overlay.open_picker(
		"指派工作角色", characters, _make_dispatch_card,
		3 + _building.potential_type, _on_dispatch_confirmed, "確認指派"
	)


## 完整素質資訊已經在 CharacterSelectPanel 左側的 CharacterDetailView 顯示,卡片只需要
## 負責「已在此工作/在別處工作/已編入小隊」這三種不可指派狀態(CharacterAvatarCard 自己
## 處理反灰+tooltip)。
func _make_dispatch_card(character: Character) -> Control:
	var is_here := BaseDispatchStore.get_dispatched_character_ids(_building.type).has(character.id)
	var is_elsewhere := not is_here and BaseDispatchStore.is_character_dispatched(character.id)
	var is_in_party := PartyStore.party != null and PartyStore.party.characteres.has(character)
	var assignable := not is_here and not is_elsewhere and not is_in_party
	var unavailable_reason := "在此工作" if is_here else ("在其他地方工作" if is_elsewhere else "已編入小隊")
	return CharacterAvatarCard.new(character, assignable, unavailable_reason)


func _on_dispatch_confirmed(character: Character) -> void:
	var success := BaseDispatchStore.dispatch(_building.type, character.id)
	if not success:
		_dispatch_error = true
	_rebuild_body()


## 兩個「選一個純頭像卡就好」的選人情境(兵營受訓/更換整團領導人)共用這顆最簡單的
## card_factory——完整資訊都在 CharacterSelectPanel 左側,卡片不需要額外的可選/不可選
## 狀態。
func _simple_avatar_card(character: Character) -> Control:
	return CharacterAvatarCard.new(character)


## 兵營:技能傳授/被動訓練 Rank 上限跟著建築等級開放,不影響戰場 COST(固定 20)。訓練中
## 名單顯示在最上面,底下是「指派角色訓練」入口——按下後疊出選人面板
## (_open_trainee_picker()),確認選擇後回到這裡展開技能清單(_training_character)。
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

	var button := Button.new()
	button.text = "指派角色訓練"
	_style_button(button)
	button.pressed.connect(func() -> void: _open_trainee_picker())
	add_child(button)


## 只列出目前空閒(未受訓/未派駐其他建築)的未禁用角色——不比照生產建築的派遣清單顯示
## 全部角色反灰,訓練是相對少發生的操作,直接濾掉不可選的人更清楚。疊加面板選定後直接
## 沿用 self 寫回 _training_character、呼叫 _rebuild_body()。
func _open_trainee_picker() -> void:
	var characters: Array[Character] = []
	for character in CharacterRosterStore.all_characteres:
		if not character.is_disabled and not BarracksTrainingStore.is_training(character.id) and not BaseDispatchStore.is_character_dispatched(character.id):
			characters.append(character)

	var overlay := CharacterSelectOverlay.new()
	get_tree().root.add_child(overlay)
	overlay.open_picker("指派角色訓練", characters, _simple_avatar_card, -1, _on_trainee_confirmed)


func _on_trainee_confirmed(character: Character) -> void:
	_training_character = character
	_rebuild_body()


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


## 工匠坊:三種配方任選一種,月結算時依 WorkshopRecipeStore 目前選定的配方換算實際產出
## (見 Scripts/Autoload/base_dispatch_store.gd 的 _resolve_recipe())。原料不夠時整個月
## 不生產、不消耗(不是部分打折),選中的配方下面直接列出本月預計消耗/取得量,讓玩家換
## 配方前先看得到會不會白忙一場。沒派工作角色時是另一回事(沒人做事,不是原料不足),
## 分開判斷、分開顯示,見 _build_recipe_preview_row() 的 has_workers。
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
## 多一行顯示,不用每種配方都攤開一次資訊。
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
		column.add_child(_build_recipe_preview_row(recipe, _building.produces, theoretical_output, has_workers))

	return column


## 6 棟高階內政建築(Building.fixed_recipe 不為 null)共用:配方固定、玩家不能選,直接
## 顯示本月預計消耗/取得量,邏輯跟工匠坊配方預覽(_build_recipe_row() 的 is_selected 分支)
## 一致,見 _build_recipe_preview_row()。
func _build_fixed_recipe_section() -> void:
	_add_label("固定消耗（資源不足時整個月不生產）：")
	var characters := BaseDispatchStore.get_dispatched_characters(_building.type)
	var level := BaseBuildingProgressStore.get_level(_building.type)
	var theoretical_output := BaseProduction.compute_monthly_yield(_building, characters, level)
	var has_workers := not characters.is_empty()
	add_child(_build_recipe_preview_row(_building.fixed_recipe, _building.produces, theoretical_output, has_workers))


## 「本月將消耗 [圖示]x數量...，取得 [圖示]x數量」這行預覽,工匠坊配方(_build_recipe_row())
## 跟固定消耗建築(_build_fixed_recipe_section())共用同一套邏輯跟排版。
func _build_recipe_preview_row(recipe: WorkshopRecipe, output_resource: int, theoretical_output: int, has_workers: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	if not has_workers:
		row.add_child(_build_preview_text("尚未指派工作角色,本月不會生產"))
		return row

	var available: Dictionary = {}
	for resource_type in recipe.inputs:
		available[resource_type] = BaseResourceStore.get_amount(resource_type)
	var result := WorkshopProduction.resolve(recipe, theoretical_output, available)
	if result.output <= 0:
		row.add_child(_build_preview_text("本月原料不足,將不會生產"))
		return row

	row.add_child(_build_preview_text("本月將消耗"))
	for resource_type in result.consumed:
		row.add_child(_build_resource_amount_chip(resource_type, result.consumed[resource_type]))
	row.add_child(_build_preview_text("，取得"))
	row.add_child(_build_resource_amount_chip(output_resource, result.output))
	return row


func _build_preview_text(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", UiStyle.PARCHMENT_SUBTITLE_COLOR)
	return label


## 資源圖示(Images/ResourceType/,見 GameEnums.resource_type_icon_path())+ 數量的最小
## 組合單位,取代原本 emoji 文字——tooltip 補上中文名稱,比照
## Scenes/PartyEdit/character_card.gd 武器圖示的既有寫法。
func _build_resource_amount_chip(resource_type: int, amount: int) -> Control:
	var chip := HBoxContainer.new()
	chip.add_theme_constant_override("separation", 2)
	chip.add_child(_build_resource_icon(resource_type))
	var label := Label.new()
	label.text = "x%d" % amount
	label.add_theme_color_override("font_color", UiStyle.PARCHMENT_SUBTITLE_COLOR)
	chip.add_child(label)
	return chip


func _build_resource_icon(resource_type: int, size: Vector2 = Vector2(26, 26)) -> TextureRect:
	var icon := TextureRect.new()
	icon.custom_minimum_size = size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = load(GameEnums.resource_type_icon_path(resource_type)) as Texture2D
	icon.tooltip_text = GameEnums.resource_string_label(resource_type)
	return icon


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
	buy_button.text = "買入（%s → 資材）" % GameEnums.resource_string_label(currency)
	buy_button.toggle_mode = true
	buy_button.button_group = direction_group
	buy_button.button_pressed = order.get("is_buy", true)
	_style_button(buy_button)
	direction_row.add_child(buy_button)

	var sell_button := Button.new()
	sell_button.text = "賣出（資材 → %s）" % GameEnums.resource_string_label(currency)
	sell_button.toggle_mode = true
	sell_button.button_group = direction_group
	sell_button.button_pressed = not order.get("is_buy", true)
	_style_button(sell_button)
	direction_row.add_child(sell_button)

	var resource_dropdown := OptionButton.new()
	## 來源 PNG 是 512x512(見 Images/ResourceType/),OptionButton 預設不會自動縮小 icon,
	## 這裡明確設 icon_max_width 限制顯示尺寸,不然下拉選單會被巨大圖示撐爆。
	resource_dropdown.add_theme_constant_override("icon_max_width", 26)
	for option in options:
		var icon := load(GameEnums.resource_type_icon_path(option.resource)) as Texture2D
		resource_dropdown.add_icon_item(icon, GameEnums.resource_string_label(option.resource), option.resource)
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
				result.source_amount, GameEnums.resource_string_label(result.source_resource),
				result.target_amount, GameEnums.resource_string_label(result.target_resource)
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
	label.text = "%s (%s) ：消耗 %s %s" % [ultimate.name, GameEnums.rank_label(ultimate.rank), GameEnums.resource_string_label(_building.produces), cost]
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
		parts.append("%s x%d" % [GameEnums.resource_string_label(resource_type), cost[resource_type]])
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
