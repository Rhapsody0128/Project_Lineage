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
## 「選一位角色」情境(派遣工作角色/更換整團領導人)一律呼叫
## Scenes/CharacterSelect/character_select_overlay.gd 的 CharacterSelectOverlay,疊加在
## 這份建築面板最上層(獨立 CanvasLayer,不是原地替換 ActionPanel 目前的內容)——self
## 全程留在畫面上不受影響,選定/取消都只是把疊加面板關掉,接下來直接沿用 self 更新狀態、
## 呼叫 _rebuild_body(),見 _open_dispatch_picker()/_open_leader_picker() 的既有寫法。
## 兵營是例外:六大項目整份交給獨立的 BarracksPanel(見 _build_barracks_panel()),六顆
## 按鈕各自 ActionPanel.open_custom() 開一份全新內容(比照 _open_weapon_craft_panel() 寫法,
## 不是原地切換這裡的內容),各自的選人流程也由那些獨立畫面自己開 CharacterSelectOverlay,
## 不沿用這裡的 _rebuild_body() 流程。城鎮中心聯姻也是例外:選聯姻角色/寄信國家改走
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
## 鐵匠鋪總覽表標記武器主屬性(GameEnums.weapon_main_stat())用的紅色,跟
## Scenes/Base/weapon_craft_panel.gd 的 _MAIN_STAT_COLOR 同一個值,兩個畫面標記方式一致。
const _WEAPON_MAIN_STAT_COLOR := Color(0.75, 0.25, 0.25)

var _building: Building
## 升級/建造失敗後單次顯示一行提示,顯示完就消耗掉,不跨 rebuild 保留。指派工作角色
## 已經改走 Scenes/Base/worker_dispatch_panel.gd 的即時指派/召回(滿額時 dispatch() 直接
## 無聲不做事),不再需要對應的錯誤旗標。
var _upgrade_error: bool = false
var _build_error: bool = false

## 祭壇/禁忌祭壇購買奧義的單次錯誤提示旗標,用法同 _build_error/_upgrade_error——商隊站/
## 黑市兌換改成每月自動執行,設定當下不會失敗,不需要對應的錯誤旗標。科技樹解鎖的錯誤
## 提示改在 TechTreePanel 自己的畫面裡處理,不需要這裡的旗標。
var _altar_error: bool = false

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

	if not BaseBuildingProgressStore.is_unlocked(_building.type):
		return

	var level := BaseBuildingProgressStore.get_level(_building.type)
	if level >= _building.max_level():
		_add_label("已達最高等級")

	if _building.type == GameEnums.BuildingType.BARRACKS:
		_build_barracks_panel()
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

	if _building.type == GameEnums.BuildingType.FORGE:
		_build_forge_section()
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
	row.add_child(_build_auto_dispatch_button())
	if construction_button != null:
		row.add_child(construction_button)
	return row


## 依 AutoDispatchRule 規則,把目前完全閒置的人力(排除小隊成員/派駐中/歷練中,見該檔案
## 開頭註解)依這棟建築的素質需求由高到低塞滿空缺工作格,填完立即 _rebuild_body() 讓工作
## 角色格/目前效率數字同步刷新——跟點空格開 WorkerDispatchPanel 手動指派是同一份
## BaseDispatchStore.dispatch(),只是候選人跟目標格由規則自動配對。
func _build_auto_dispatch_button() -> Button:
	var button := Button.new()
	button.text = "自動派遣"
	_style_button(button)
	button.pressed.connect(func() -> void:
		AutoDispatchRule.auto_dispatch(_building)
		_rebuild_body()
	)
	return button


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
		var owned: int = BaseResourceStore.get_display_amount(resource_type)
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
		var amount: int = BaseResourceStore.get_display_amount(resource_type)
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
	# 沿用 ActionPanel.DEFAULT_MIN_SIZE(1500x750)——那只是「最小」尺寸,不是固定尺寸:
	# StrongholdMarriagePanel 內容比 750 矮就照最小高度長,留白墊在下面;內容比 750 高時
	# PanelContainer 本來就會照子節點需要的高度自動長高,沒必要另外傳更小的高度硬擠。
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


## 鐵匠鋪:六武器類型總覽表(每列一種武器,欄位是六大素質各自的點數、RANK、總素質分開
## 三種顯示,最右邊一欄是該列專屬的「打造武器」鈕——素質欄順序沿用 CharacterDetailView.
## POTENTIAL_GRID_ORDER 跟角色面板一致)。「變更武器」按鈕跟建造/升級鈕一起塞進標題列
## (ActionPanel.set_title_action_button(),× 左邊同一排),不再佔內容區塊一整排——見
## _build_forge_title_row()。打造武器(WeaponCraftPanel)固定綁該列的武器類型,不再有
## 「先選類型」這一步,直接依表格點的是哪一列決定;變更武器(WeaponEquipPanel)幫指定角色
## 把手持武器類型換成另一種,比較兩種武器類型的全域素質加成差異,兩者是分開的獨立功能。
func _build_forge_section() -> void:
	ActionPanel.set_title_action_button(_build_forge_title_row())

	var grid := GridContainer.new()
	grid.columns = CharacterDetailView.POTENTIAL_GRID_ORDER.size() + 4
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 6)

	var headers: Array[String] = ["武器"]
	for potential_type in CharacterDetailView.POTENTIAL_GRID_ORDER:
		headers.append(GameEnums.potential_label(potential_type))
	headers.append("RANK")
	headers.append("總素質")
	headers.append("")
	for header_text in headers:
		var header := Label.new()
		header.text = header_text
		header.add_theme_color_override("font_color", UiStyle.PARCHMENT_SUBTITLE_COLOR)
		grid.add_child(header)

	for weapon_type in GameEnums.WeaponType.values():
		_add_forge_weapon_row(grid, weapon_type)
	add_child(grid)


## 建造/升級鈕(_build_title_action_row(),FORGE 是非生產類建築,回傳單顆 Button 或 null)
## 跟「變更武器」合併成同一排塞進標題列,取代 _rebuild_body() 一開始已經設過一次的版本
## (ActionPanel.set_title_action_button() 换新的會自動 queue_free 舊的,不會重複殘留,見
## action_panel.gd)。「打造武器」不放在這裡——固定綁武器類型,只能從下面表格每列自己的
## 按鈕進入(見 _add_forge_weapon_row())。
func _build_forge_title_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var construction_button := _build_title_action_row()
	if construction_button != null:
		row.add_child(construction_button)

	var change_button := Button.new()
	change_button.text = "變更武器"
	UiStyle.style_panel_action_button(change_button)
	change_button.pressed.connect(_open_weapon_equip_panel)
	row.add_child(change_button)

	return row


func _add_forge_weapon_row(grid: GridContainer, weapon_type: int) -> void:
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(24, 24)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = load(GameEnums.weapon_icon_path(weapon_type)) as Texture2D

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	name_row.add_child(icon)
	var name_label := Label.new()
	name_label.text = GameEnums.weapon_label(weapon_type)
	name_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	name_row.add_child(name_label)
	grid.add_child(name_row)

	var equipped: WeaponInstance = WeaponStore.get_equipped(weapon_type)
	var main_stat := GameEnums.weapon_main_stat(weapon_type)
	for potential_type in CharacterDetailView.POTENTIAL_GRID_ORDER:
		var stat_label := Label.new()
		stat_label.text = str(equipped.get_point(potential_type))
		## 武器主屬性(例如劍的力量)這一格標紅色,比照 WeaponCraftPanel 比較表的
		## _MAIN_STAT_COLOR 用同一個紅,兩個畫面標記方式一致。
		stat_label.add_theme_color_override("font_color", _WEAPON_MAIN_STAT_COLOR if potential_type == main_stat else UiStyle.PARCHMENT_TEXT_COLOR)
		grid.add_child(stat_label)

	var rank_label := Label.new()
	rank_label.text = "%s級" % GameEnums.rank_label(equipped.rank_type)
	rank_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	grid.add_child(rank_label)

	var total_label := Label.new()
	total_label.text = str(equipped.total_points())
	total_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	grid.add_child(total_label)

	var craft_button := Button.new()
	craft_button.text = "打造"
	UiStyle.style_panel_action_button(craft_button)
	craft_button.pressed.connect(func() -> void: _open_weapon_craft_panel(weapon_type))
	grid.add_child(craft_button)


## 表格每列的「打造武器」鈕開啟 WeaponCraftPanel,固定綁該列的武器類型(標題跟著顯示
## 「打造武器（武器名）」)——寫法比照 _open_stronghold_marriage_panel():整份 ActionPanel
## 內容替換(不是疊加),on_close 重新呼叫 BaseBuildingEvent.open_action_panel() 重建鐵匠鋪
## 面板,不嘗試復用已被釋放的 self。
func _open_weapon_craft_panel(weapon_type: int) -> void:
	var building := _building
	var panel := WeaponCraftPanel.new()
	var title := "打造武器（%s）" % GameEnums.weapon_label(weapon_type)
	ActionPanel.open_custom(title, panel, func(): BaseBuildingEvent.open_action_panel(building))
	panel.setup(weapon_type, func(): BaseBuildingEvent.open_action_panel(building))


## 「變更武器」按鈕開啟 WeaponEquipPanel,同樣是整份 ActionPanel 內容替換。
func _open_weapon_equip_panel() -> void:
	var building := _building
	var panel := WeaponEquipPanel.new()
	ActionPanel.open_custom("變更武器", panel, func(): BaseBuildingEvent.open_action_panel(building))
	panel.setup(func(): BaseBuildingEvent.open_action_panel(building))


## 有配方(fixed_recipe 或工匠坊)的建築不重複顯示這行——那些建築的「理論上限」已經改成
## 「最大產能」顯示在配方預覽區塊(_build_recipe_preview_row()),跟「本月產能」(原料實際
## 夠用、可能因為原料不足而低於最大產能的量)並排,不需要這裡再顯示一次同一個數字。
func _build_efficiency_label() -> void:
	if _building.fixed_recipe != null or _building.type == GameEnums.BuildingType.WORKSHOP:
		return
	var characters := BaseDispatchStore.get_dispatched_characters(_building.type)
	var level := BaseBuildingProgressStore.get_level(_building.type)
	var monthly_yield := BaseProduction.compute_monthly_yield(_building, characters, level)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.add_child(_build_plain_text("目前效率：%d" % monthly_yield))
	row.add_child(_build_resource_icon(_building.produces))
	row.add_child(_build_plain_text("/月"))
	add_child(row)
	## 倉庫已滿時月結算(BaseDispatchStore.settle())整棟跳過、不生產(見該檔案),這裡
	## 額外補一行提示,不然玩家看著「目前效率：X」的數字卻怎麼等都等不到入庫,一頭霧水。
	if BaseResourceStore.is_full(_building.produces):
		_add_label("倉庫已滿,本月不會生產")


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


## 開啟 Scenes/Base/worker_dispatch_panel.gd 的三塊版面(左側角色詳情/右上工作安排列/
## 右下角色清單),點列表卡片即時指派、點安排列頭像即時召回,沒有單一結果可以 confirm,
## 所以不走 CharacterSelectOverlay.open_picker() 那條「選一個再確認」的路,改用
## open_content() 塞內容——疊加視窗開著時可以連續調整好幾個人,關閉時(接 tree_exiting)
## 才重建這份建築面板,反映最新的工作角色列/效率數字。
func _open_dispatch_picker() -> void:
	var overlay := CharacterSelectOverlay.new()
	get_tree().root.add_child(overlay)
	overlay.open_content("指派工作角色", WorkerDispatchPanel.new(_building))
	overlay.tree_exiting.connect(_rebuild_body)


## 「選一個純頭像卡就好」的選人情境(更換整團領導人)用這顆最簡單的 card_factory——
## 完整資訊都在 CharacterSelectPanel 左側,卡片不需要額外的可選/不可選狀態。
func _simple_avatar_card(character: Character) -> Control:
	return CharacterAvatarCard.new(character)


## 兵營:六大項目(傳授/歷練/戰場擴充/戰術格開發/隊長訓練/變換隊形)整份交給獨立的
## BarracksPanel(Scenes/Base/barracks_panel.gd)——自學訓練已被「傳授」(師徒制)完全
## 取代,見 System/base/barracks_teaching_rule.gd。這裡只負責掛載,不像 WeaponCraftPanel
## 那樣另開一層 ActionPanel 內容(兵營沒有「先看總覽表再點進子畫面」的需求,六個分頁本身
## 就是兵營的全部內容)。
func _build_barracks_panel() -> void:
	var panel := BarracksPanel.new()
	panel.setup(_building)
	add_child(panel)


## 工匠坊:三種配方任選一種,月結算時依 WorkshopRecipeStore 目前選定的配方換算實際產出
## (見 Scripts/Autoload/base_dispatch_store.gd 的 _resolve_recipe())。原料不夠時按比例
## 部分生產,不是整個月掛零(見 System/base/workshop_production.gd),選中的配方下面直接
## 列出「最大產能」跟本月實際能做到的「本月產能」,讓玩家換配方前先看得到原料夠不夠撐滿。
## 沒派工作角色時是另一回事(沒人做事,不是原料不足),分開判斷、分開顯示,見
## _build_recipe_preview_row() 的 has_workers。
func _build_recipe_section() -> void:
	_add_label("配方（原料不足時按比例部分生產）：")
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
## 顯示最大產能/本月產能,邏輯跟工匠坊配方預覽(_build_recipe_row() 的 is_selected 分支)
## 一致,見 _build_recipe_preview_row()。
func _build_fixed_recipe_section() -> void:
	_add_label("固定消耗（原料不足時按比例部分生產）：")
	var characters := BaseDispatchStore.get_dispatched_characters(_building.type)
	var level := BaseBuildingProgressStore.get_level(_building.type)
	var theoretical_output := BaseProduction.compute_monthly_yield(_building, characters, level)
	var has_workers := not characters.is_empty()
	add_child(_build_recipe_preview_row(_building.fixed_recipe, _building.produces, theoretical_output, has_workers))


## 「最大產能 [圖示]xZ，本月產能 [圖示]xY（消耗 [圖示]xX...）」這行預覽,工匠坊配方
## (_build_recipe_row())跟固定消耗建築(_build_fixed_recipe_section())共用同一套邏輯跟
## 排版。最大產能(theoretical_output)是工作角色能做到的理論上限,不受原料夠不夠影響;
## 本月產能是原料實際夠用的量,原料不足時會按比例小於最大產能(見
## System/base/workshop_production.gd 的 resolve()),兩個數字分開顯示才看得出是不是被
## 原料卡住。result.output/consumed 都是可能帶小數的 float(零頭留在 BaseResourceStore
## 裡累積到下個月),這裡無條件捨去成整數顯示,不影響底下真正入庫的精確值。產物倉庫已滿
## 時月結算(BaseDispatchStore.settle())整棟跳過、不生產也不消耗(見該檔案),這裡要用
## 同一條件先擋掉,不然預覽會說「本月產能 X」卻實際上一滴都不會生產,跟真正結算兜不起來。
func _build_recipe_preview_row(recipe: WorkshopRecipe, output_resource: int, theoretical_output: int, has_workers: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	if not has_workers:
		row.add_child(_build_preview_text("尚未指派工作角色,本月不會生產"))
		return row

	if BaseResourceStore.is_full(output_resource):
		row.add_child(_build_preview_text("倉庫已滿,本月不會生產"))
		return row

	var available: Dictionary = {}
	for resource_type in recipe.inputs:
		available[resource_type] = BaseResourceStore.get_amount(resource_type)
	var result := WorkshopProduction.resolve(recipe, theoretical_output, available)

	row.add_child(_build_preview_text("最大產能"))
	row.add_child(_build_resource_amount_chip(output_resource, theoretical_output))

	if result.output <= 0.0:
		row.add_child(_build_preview_text("，原料枯竭，本月無法生產"))
		return row

	row.add_child(_build_preview_text("，本月產能"))
	row.add_child(_build_resource_amount_chip(output_resource, floori(result.output)))
	row.add_child(_build_preview_text("（消耗"))
	for resource_type in result.consumed:
		row.add_child(_build_resource_amount_chip(resource_type, floori(result.consumed[resource_type])))
	row.add_child(_build_preview_text("）"))
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
## 每棟建築可能同時開好幾條「貿易路線」(見 System/base/base_exchange.gd route_count(),
## 「市集通商」科技線加成,基礎 1 條、最多再 +4 條),路線之間各自獨立、可同時交易不同
## 資材,不共用額度;每條路線的交易量上限不是寫死的,是「目前派駐人數 × 20」(見
## BaseExchange.route_capacity()),沒派人就是 0。每月結算時自動執行一次;來源資源不夠時
## 整個月不換(不會部分兌換、不會扣成負數),目標資源倉庫快滿時改成只買/賣到剛好塞滿、
## 花費跟著等比例減少(不會整月不換,也不會超買後被倉庫上限吃掉浪費的部分)。拉桿拖曳中
## 只更新預覽跟即時寫回 BaseExchangeStore,不整包 _rebuild_body(),避免拖曳被打斷。
func _build_exchange_section() -> void:
	var building_type := _building.type
	var worker_count := BaseDispatchStore.get_dispatched_characters(building_type).size()
	var capacity := BaseExchange.route_capacity(worker_count)
	var route_count := BaseExchange.route_count()

	_add_label("每月自動兌換（來源資源不夠時該月不換；目標倉庫快滿時只買/賣到剛好塞滿，花費等比例減少）：")
	_add_label("目前派駐 %d 人，每條貿易路線交易量上限 %d，共 %d 條路線同時生效（見「市集通商」科技線）：" % [worker_count, capacity, route_count])

	for route_index in range(route_count):
		if route_index > 0:
			add_child(HSeparator.new())
		_build_exchange_route_row(building_type, route_index, capacity)


func _build_exchange_route_row(building_type: GameEnums.BuildingType, route_index: int, capacity: int) -> void:
	var currency := BaseExchange.currency_for(building_type)
	var currency_icon := load(GameEnums.resource_type_icon_path(currency)) as Texture2D
	var options := BaseExchange.options_for(building_type)
	var order := BaseExchangeStore.get_order(building_type, route_index)

	_add_label("路線 %d：" % (route_index + 1))

	var direction_group := ButtonGroup.new()
	var direction_row := HBoxContainer.new()
	direction_row.add_theme_constant_override("separation", 8)
	add_child(direction_row)

	## 方向鈕改用貨幣圖示取代文字資源名(比照 _build_resource_icon() 既有寫法),箭頭文字
	## 保留指示買賣方向,"資材"端由下方 resource_dropdown 的圖示表達。
	var buy_button := Button.new()
	buy_button.text = "買入（→ 資材）"
	buy_button.icon = currency_icon
	buy_button.add_theme_constant_override("icon_max_width", 22)
	buy_button.toggle_mode = true
	buy_button.button_group = direction_group
	buy_button.button_pressed = order.get("is_buy", true)
	_style_button(buy_button)
	direction_row.add_child(buy_button)

	var sell_button := Button.new()
	sell_button.text = "賣出（資材 →）"
	sell_button.icon = currency_icon
	sell_button.add_theme_constant_override("icon_max_width", 22)
	sell_button.toggle_mode = true
	sell_button.button_group = direction_group
	sell_button.button_pressed = not order.get("is_buy", true)
	_style_button(sell_button)
	direction_row.add_child(sell_button)

	var resource_dropdown := OptionButton.new()
	## 來源 PNG 是 512x512(見 Images/ResourceType/),OptionButton 預設不會自動縮小 icon,
	## 這裡明確設 icon_max_width 限制顯示尺寸,不然下拉選單會被巨大圖示撐爆。下拉展開的
	## 清單其實是獨立的 PopupMenu 子節點(get_popup()),不會繼承設在 OptionButton 本體上的
	## instance override,兩邊都要設,否則按鈕本身圖示正常、點開清單卻整包被撐爆。
	resource_dropdown.add_theme_constant_override("icon_max_width", 26)
	resource_dropdown.get_popup().add_theme_constant_override("icon_max_width", 26)
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
	slider.max_value = capacity
	slider.step = 1
	slider.value = order.get("units", 0)
	slider.custom_minimum_size = Vector2(320, 0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider_row.add_child(slider)

	var units_label := Label.new()
	units_label.custom_minimum_size = Vector2(60, 0)
	units_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	slider_row.add_child(units_label)

	## 預覽改用資源圖示+數量(_build_resource_amount_chip(),比照工匠坊產能預覽既有寫法),
	## 取代原本純文字資源名。preview_row 每次拉桿異動就整包清空重建,不是原地改文字。
	var preview_row := HBoxContainer.new()
	preview_row.add_theme_constant_override("separation", 4)
	add_child(preview_row)

	var refresh_preview := func() -> void:
		var is_buy := buy_button.button_pressed
		var resource := resource_dropdown.get_selected_id()
		var units := int(slider.value)
		units_label.text = "x%d" % units
		BaseExchangeStore.set_order(building_type, route_index, is_buy, resource, units)
		for child in preview_row.get_children():
			child.queue_free()
		var result := BaseExchangeStore.preview(building_type, route_index)
		if result.source_amount <= 0:
			preview_row.add_child(_build_preview_text("尚未設定兌換數量"))
			return
		preview_row.add_child(_build_preview_text("本月將消耗"))
		preview_row.add_child(_build_resource_amount_chip(result.source_resource, result.source_amount))
		preview_row.add_child(_build_preview_text("，取得"))
		preview_row.add_child(_build_resource_amount_chip(result.target_resource, result.target_amount))

	buy_button.toggled.connect(func(_pressed: bool) -> void: refresh_preview.call())
	sell_button.toggled.connect(func(_pressed: bool) -> void: refresh_preview.call())
	resource_dropdown.item_selected.connect(func(_index: int) -> void: refresh_preview.call())
	slider.value_changed.connect(func(_value: float) -> void: refresh_preview.call())

	refresh_preview.call()


## 祭壇/禁忌祭壇:購買奧義直接對接既有 UltimateStore 的次數系統,消耗資源用
## _building.produces(祭壇=信仰、禁忌祭壇=詛咒),不用另外分流。9 個奧義(F~SSS)固定
## 全部列出一張表(名稱/Rank/價格/持有/購買鈕),不是「已擁有」「可購買」拆兩段各自列——
## 建築等級不足、還買不到的 Rank 照樣留一行在表裡,價格欄改顯示「等級不足」、購買鈕
## disabled,讓玩家一眼看到整條奧義階梯還差幾級解鎖,不用切換 tooltip 才看得到說明,長版
## 效果說明直接開一欄顯示(Rank 跟價格之間),不用再靠 tooltip 才看得到。價格欄跟最上方的倉庫存量一律用
## _build_resource_icon() 的資源圖示取代文字資源名,比照 _build_warehouse_section() 既有
## 寫法。最上方顯示的是「倉庫裡的信仰/詛咒庫存」(BaseResourceStore.get_amount()),
## 不是奧義持有次數——奧義持有次數已經在表格「持有」欄逐行顯示了,不用在最上面重複。
func _build_altar_section() -> void:
	var rank_cap := BaseBuildingProgressStore.get_rank(_building.type)
	var ultimates := (
		UltimateLibrary.self_ultimates() if _building.type == GameEnums.BuildingType.ALTAR
		else UltimateLibrary.enemy_ultimates()
	)

	var stock_row := HBoxContainer.new()
	stock_row.add_theme_constant_override("separation", 6)
	stock_row.add_child(_build_resource_icon(_building.produces))
	var stock_label := Label.new()
	stock_label.text = "目前總共%s：%d" % [
		GameEnums.resource_string_label(_building.produces), BaseResourceStore.get_display_amount(_building.produces)
	]
	stock_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	stock_row.add_child(stock_label)
	add_child(stock_row)

	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 6)
	for header_text in ["奧義", "Rank", "描述", "價格", "持有", ""]:
		var header := Label.new()
		header.text = header_text
		header.add_theme_color_override("font_color", UiStyle.PARCHMENT_SUBTITLE_COLOR)
		grid.add_child(header)

	for ultimate in ultimates:
		_add_ultimate_row(grid, ultimate, rank_cap)
	add_child(grid)

	if _altar_error:
		_add_label("資源不足")
		_altar_error = false


func _add_ultimate_row(grid: GridContainer, ultimate: Ultimate, rank_cap: GameEnums.RankType) -> void:
	var unlocked := ultimate.rank <= rank_cap
	var cost := BaseAltar.cost_for_rank(ultimate.rank, _building.type)
	var resource_type := _building.produces

	var name_label := Label.new()
	name_label.text = ultimate.name
	name_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	grid.add_child(name_label)

	var rank_label := Label.new()
	rank_label.text = GameEnums.rank_label(ultimate.rank)
	rank_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	grid.add_child(rank_label)

	var description_label := Label.new()
	description_label.text = ultimate.description
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	description_label.custom_minimum_size = Vector2(320, 0)
	description_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	grid.add_child(description_label)

	var price_box := HBoxContainer.new()
	price_box.add_theme_constant_override("separation", 4)
	if unlocked:
		price_box.add_child(_build_resource_icon(resource_type, Vector2(20, 20)))
		var price_label := Label.new()
		price_label.text = str(cost)
		price_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
		price_box.add_child(price_label)
	else:
		var locked_label := Label.new()
		locked_label.text = "等級不足"
		locked_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
		price_box.add_child(locked_label)
	grid.add_child(price_box)

	var owned_label := Label.new()
	owned_label.text = str(UltimateStore.uses_remaining(ultimate))
	owned_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	grid.add_child(owned_label)

	var button := Button.new()
	button.text = "購買"
	_style_button(button)
	button.disabled = not unlocked
	button.pressed.connect(func() -> void:
		if BaseResourceStore.can_afford({resource_type: cost}):
			BaseResourceStore.spend({resource_type: cost})
			UltimateStore.add_uses(ultimate, 1)
			_rebuild_body()
		else:
			_altar_error = true
			_rebuild_body()
	)
	grid.add_child(button)


## 科學研究所:15 格科技樹,依分類分組顯示,門檻/科研消耗見 TechLibrary。效果本身
## (升級耗材-10%、移動速度+10%等)目前只追蹤解鎖狀態,尚未接上實際加成邏輯。
## 科技樹本體(90 個節點的樹狀圖)是獨立場景 Scenes/Tech/tech_tree.tscn(不是 ActionPanel
## 疊加內容,樹狀圖太大,比照祖譜走全場景切換),這裡只放一顆進入鈕。
func _build_tech_section() -> void:
	_add_label("科技樹(花科研永久解鎖,依科學研究所等級與前置科技解鎖)。")
	var open_button := Button.new()
	open_button.text = "開啟科技樹"
	_style_button(open_button)
	open_button.pressed.connect(_open_tech_tree)
	add_child(open_button)


## 先關掉這層 ActionPanel(它是持續存活的 autoload CanvasLayer,不關掉會疊在新場景上面),
## 再切場景過去——返回時科技樹場景會用 SceneHandoffStore 交接回「要重開科學研究所」,
## 見 Scenes/Tech/tech_tree.gd 開頭註解與 Scenes/Base/base_inner.gd 的接收端。
##
## 進根據地建築面板這趟本來就先繞去 Dialogue 場景播「你走進了...」(next_scene_path 留空,
## 對話播完後畫面留在背景給 ActionPanel 疊加,見 BaseBuildingEvent),所以這裡是「先繞去
## 中繼場景才抵達真正目的地」的情境(見 NavigationStore 開頭註解)——不能呼叫
## NavigationStore.go_to(),它會在切場景當下自動抓 current_scene,抓到的會是那個 Dialogue
## 而不是 base.tscn。比照 TownGateEvent/CastleSiegeEvent 的既有寫法:先手動
## push_return_scene_path() 明講邏輯上的上一頁是 base.tscn,再用不記錄堆疊的
## change_scene_to_file() 切過去,go_back() 才會直接回到根據地本體而不是回放那句舊對話
## (那句對話的 SceneHandoffStore mailbox 是 peek() 不會清空,回放到還會再次觸發
## on_finished 重新彈出這層 ActionPanel,造成「按 X 要點兩次」的假象)。
func _open_tech_tree() -> void:
	ActionPanel.close(false)
	NavigationStore.push_return_scene_path("res://Scenes/Base/base.tscn")
	var error := get_tree().change_scene_to_file("res://Scenes/Tech/tech_tree.tscn")
	if error != OK:
		printerr("Error changing scene to tech tree: ", error)


func _format_cost(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for resource_type in cost:
		parts.append("%s x%d" % [GameEnums.resource_string_label(resource_type), cost[resource_type]])
	return "、".join(parts)


## 按鈕木牌樣式已搬到 UiStyle.style_panel_action_button()(多個面板腳本共用,不只這裡),
## 這裡留一個薄委派避免重寫檔案內全部既有呼叫點。
func _style_button(button: Button) -> void:
	UiStyle.style_panel_action_button(button)


func _add_label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	add_child(label)
