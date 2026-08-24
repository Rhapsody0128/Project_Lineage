class_name CharacterDetailView
extends VBoxContainer

# =========================================================
# 角色詳細資訊的直式排版元件:最上面立繪/姓名/年齡/性別,下方分頁籤
# (屬性/血統/家族)。彈出式 CharacterPanel 與 CharacterRoster(角色列表
# 畫面左 1/3 欄)共用同一顆完整元件,不再各自維護一份呈現邏輯。
#
# 分頁內容各自包一層 ScrollContainer——外層 CharacterPanel 面板本身是
# 固定尺寸(不隨內容被撐高,見 character_panel.tscn 的 PanelBox
# custom_minimum_size),內容多到放不下時要在分頁內部捲動,而不是把
# TabContainer/面板本身的最小尺寸往上頂。
#
# 排版風格統一成兩種:區塊標題/立繪/大型圖表(雷達圖/技能格/血統計量表)
# 置中或滿版鋪開;單行數值(等級/武器/EXP/六大素質/血統百分比)一律拆成
# 「標題靠左、數值靠右」的兩端對齊列(_build_stat_row()),不要有的置中
# 有的靠左混搭。分頁內容外圍統一包一層 TAB_CONTENT_PADDING 的
# MarginContainer,避免文字/計量表貼齊分頁邊緣。
#
# 程式化建構節點,比照 HeaderBar/CharacterCard 等既有共用元件的慣例,
# 不另外拆 .tscn。
#
# 用法:var view := CharacterDetailView.new(); parent.add_child(view);
# view.set_character(character, battle_character)。battle_character 選填,語意跟
# CharacterPotentialRadar.set_character() 一致(戰場即時數值)。
# =========================================================

## 這顆元件自己攜帶的最小寬度,在 _ready() 套進自己的 custom_minimum_size.x——寬度是這顆
## 元件的規格,不是呼叫端的事。CharacterPanel(彈出面板)、CharacterRoster、
## CharacterSelectPanel、StrongholdMarriagePanel、MarriageProposalPanel 五處呼叫端只需要
## 把這顆元件塞進自己的版面,不要再各自寫 custom_minimum_size = Vector2(PANEL_WIDTH, 0)
## 或任何其他寫死的寬度數字撐出同一個寬度——那是在重複宣告這顆元件已經自己攜帶的規格,
## 之後要調寬度只改這裡一處就好。高度刻意不設下限:這顆元件常被塞進高度不一的彈窗/欄位
## (固定 840 高的 CharacterPanel、跟 RosterPanel 同高的 CharacterRoster 欄位、
## ActionPanel 內容區塊……),固定最小高度會在比較矮的容器裡把外層撐爆,交給父層
## Container(搭配 SIZE_EXPAND_FILL)決定實際高度才對。
const PANEL_WIDTH := 320.0

## 技能格 2*2 排列,GridContainer columns=2。
const SKILL_SLOT_COUNT := 4
const SKILL_GRID_COLUMNS := 2
const SKILL_SLOT_MIN_SIZE := Vector2(130, 44)
const PORTRAIT_SIZE := Vector2(140, 140)
## BATTLE_COST 佔位形狀預覽——彈出式面板空間比舊版橫式寬裕,放大一點方便看清楚形狀
const BATTLE_COST_FRAME_SIZE := Vector2(140, 140)
const BATTLE_COST_CELL_SIZE := 26.0
const WEAPON_ICON_SIZE := Vector2(20, 20)
const EXP_BAR_HEIGHT := 10.0
const EXP_BAR_FILL := Color(0.55, 0.8, 1.0)
const EXP_BAR_BG := Color(0.1, 0.1, 0.12)
const RADAR_MIN_SIZE := Vector2(280, 220)
const BLOODLINE_BAR_HEIGHT := 10.0
const BLOODLINE_BAR_FILL := Color(0.75, 0.78, 0.86)
const BLOODLINE_BAR_BG := Color(0.1, 0.1, 0.12)

## 家族分頁每個成員列的小頭像,比 header 的 PORTRAIT_SIZE 小一號——一行只需要
## 辨識用,不需要跟主要立繪搶視覺。
const FAMILY_PORTRAIT_SIZE := Vector2(60, 60)

## 分頁內容跟 TabContainer 邊緣的內距,避免捲動內容貼邊
const TAB_CONTENT_PADDING := 14

const SKILL_SLOT_BG := Color(0.1, 0.1, 0.14, 0.6)
const SKILL_SLOT_BORDER := Color(0.4, 0.46, 0.66, 1)

const TRAIT_COLOR_POSITIVE := Color(0.55, 0.85, 0.55)
const TRAIT_COLOR_NEGATIVE := Color(0.9, 0.5, 0.5)
const TRAIT_COLOR_NEUTRAL := Color(0.8, 0.8, 0.8)

## 技能綁定的武器跟目前手持武器不符時,整格反灰(半透明)提示無法施放
const SKILL_DISABLED_MODULATE := Color(1, 1, 1, 0.4)
const SKILL_ENABLED_MODULATE := Color(1, 1, 1, 1)

## 六大素質列的排列順序(2 欄 GridContainer 依序左上→右下填格),
## 對照使用者要的排版:力量/敏捷、體質/靈巧、智慧/信仰。
const POTENTIAL_GRID_ORDER := [
	GameEnums.PotentialType.STRENGTH, GameEnums.PotentialType.AGILITY,
	GameEnums.PotentialType.VITALITY, GameEnums.PotentialType.DEXTERITY,
	GameEnums.PotentialType.INTELLIGENCE, GameEnums.PotentialType.MENTALITY,
]

var portrait_texture: TextureRect
var name_label: Label
var age_label: Label
var status_label: Label
var gender_label: Label
var level_value_label: Label
var weapon_icon: TextureRect
var exp_bar: ProgressBar
var exp_value_label: Label
var battle_cost_view: BattleCostView
var potential_value_labels: Array[Label] = []
var radar: CharacterPotentialRadar
var bloodline_list: VBoxContainer
var bloodline_rank_value_label: Label
var skill_row: GridContainer
var trait_list: HFlowContainer
var parent_list: VBoxContainer
var mate_list: VBoxContainer
var children_list: VBoxContainer

var current_character: Character


func _ready() -> void:
	# 寬度是這顆元件自己的規格,見上面 PANEL_WIDTH 註解——呼叫端不用也不該再設。
	custom_minimum_size.x = PANEL_WIDTH
	add_theme_constant_override("separation", 10)

	add_child(_build_identity_header())
	add_child(HSeparator.new())

	var tabs := TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# 分頁內容區塊不需要引擎預設那塊body底色——面板本身(彈出式 CharacterPanel 或
	# CharacterRoster/MarriageProposal 內嵌的羊皮紙底)已經是背景了,疊一層
	# TabContainer 自己的底色只會多一塊不必要的色塊。
	tabs.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	tabs.add_theme_stylebox_override("tab_selected", UiStyle.bordered_panel(
		Color(0.85, 0.72, 0.5, 0.6), UiStyle.PARCHMENT_ROW_BORDER, 1, 8, 10.0, 6.0
	))
	tabs.add_theme_stylebox_override("tab_unselected", UiStyle.bordered_panel(
		Color(0.55, 0.42, 0.26, 0.12), Color(0, 0, 0, 0), 0, 8, 10.0, 6.0
	))
	tabs.add_theme_stylebox_override("tab_hovered", UiStyle.bordered_panel(
		Color(0.7, 0.55, 0.35, 0.35), UiStyle.PARCHMENT_ROW_BORDER, 1, 8, 10.0, 6.0
	))
	tabs.add_theme_color_override("font_selected_color", UiStyle.PARCHMENT_TEXT_COLOR)
	tabs.add_theme_color_override("font_unselected_color", UiStyle.PARCHMENT_SUBTITLE_COLOR)
	tabs.add_theme_color_override("font_hovered_color", UiStyle.PARCHMENT_TEXT_COLOR)
	add_child(tabs)

	tabs.add_child(_build_attribute_tab())
	tabs.add_child(_build_bloodline_tab())
	tabs.add_child(_build_family_tab())


## 任何場景都可呼叫:view.set_character(character, battle_character)。傳 null 代表清空
## (面板關閉/離開角色列表選取時停止雷達圖逐幀重繪,見 CharacterPotentialRadar)。
func set_character(character: Character, battle_character: BattleCharacter = null) -> void:
	current_character = character

	if character == null:
		portrait_texture.texture = null
		name_label.text = ""
		age_label.text = ""
		gender_label.text = ""
		bloodline_rank_value_label.text = ""
		radar.set_character(null)
		return

	portrait_texture.texture = _load_face_texture(character.face_path)
	name_label.text = character.full_name
	age_label.text = "%d" % character.age
	status_label.text = CharacterStatusRule.get_status_label(character)
	gender_label.text = GameEnums.gender_symbol(character.gender)
	bloodline_rank_value_label.text = GameEnums.rank_label(character.noble_bloodline_rank)

	level_value_label.text = "%d" % character.level_system.level
	_update_exp_bar(character.level_system)
	weapon_icon.texture = load(GameEnums.weapon_icon_path(character.weapon)) as Texture2D
	weapon_icon.tooltip_text = GameEnums.weapon_label(character.weapon)

	var is_leader := battle_character != null and battle_character.is_leader

	battle_cost_view.weapon = character.weapon
	battle_cost_view.is_leader = is_leader
	battle_cost_view.battle_cost = character.battle_cost

	radar.set_character(character, battle_character)
	_populate_bloodline(character.bloodline)

	_update_potential_labels(character, battle_character)
	_populate_skills(character)
	_populate_traits(character.traits)
	_populate_family(character)


## 區塊標題顏色,統一用 UiStyle 的深咖啡系 PARCHMENT_SUBTITLE_COLOR。
func _title_color() -> Color:
	return UiStyle.PARCHMENT_SUBTITLE_COLOR


## 一般內文字色(標題以外的說明/數值文字),統一用 UiStyle 的 PARCHMENT_TEXT_COLOR
## 蓋掉引擎預設的淺色文字。
func _apply_body_text_color(label: Label) -> void:
	label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)


## 「標題靠左、數值靠右」的兩端對齊列(對照 CSS 的 justify-content: space-between),
## 面板內所有單行數值(等級/EXP/六大素質/血統百分比)統一用這個排版,不要有的置中
## 有的靠左。回傳列本身跟數值 Label,呼叫端保留數值 Label 的參照供之後更新內容。
func _build_stat_row(caption: String) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var caption_label := Label.new()
	caption_label.text = caption
	caption_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption_label.add_theme_font_size_override("font_size", 15)
	_apply_body_text_color(caption_label)
	row.add_child(caption_label)

	var value_label := Label.new()
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", 15)
	_apply_body_text_color(value_label)
	row.add_child(value_label)

	return {"row": row, "caption_label": caption_label, "value_label": value_label}


## 立繪(沿用放大的 Character.face_path 大頭貼,紙娃娃/全身立繪系統尚未製作,
## 見遊戲企劃設定總整理.md 十一 紙娃娃系統)左半 + 姓名/年齡/性別/血統評級右半,
## 兩邊各佔 header 一半寬度(立繪置中不被撐大,比照 _build_attribute_tab() 的
## battle_cost_frame+CenterContainer 寫法);右半四行都是 _build_stat_row() 的
## 「標題靠左、數值靠右」列(justify-content: space-between),跟下面素質分頁同一套
## 排版語彙,不再是單純堆疊的純文字。血統評級(Character.noble_bloodline_rank)排在
## 性別下面一列,是使用者指定的位置——緊貼頭像,不用切到血統分頁才看得到評級。
func _build_identity_header() -> Control:
	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", 14)

	var portrait_frame := PanelContainer.new()
	portrait_frame.custom_minimum_size = PORTRAIT_SIZE
	portrait_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(portrait_frame)

	var portrait_center := CenterContainer.new()
	portrait_frame.add_child(portrait_center)

	portrait_texture = TextureRect.new()
	portrait_texture.custom_minimum_size = PORTRAIT_SIZE
	portrait_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_texture.stretch_mode = TextureRect.STRETCH_SCALE
	portrait_center.add_child(portrait_texture)

	var info_column := VBoxContainer.new()
	info_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info_column.add_theme_constant_override("separation", 8)
	header.add_child(info_column)

	var name_row := _build_stat_row("姓名")
	name_label = name_row["value_label"]
	info_column.add_child(name_row["row"])

	var age_row := _build_stat_row("年齡")
	age_label = age_row["value_label"]
	info_column.add_child(age_row["row"])

	var status_row := _build_stat_row("狀態")
	status_label = status_row["value_label"]
	info_column.add_child(status_row["row"])

	var gender_row := _build_stat_row("性別")
	gender_label = gender_row["value_label"]
	info_column.add_child(gender_row["row"])

	var rank_row := _build_stat_row("評級")
	bloodline_rank_value_label = rank_row["value_label"]
	info_column.add_child(rank_row["row"])

	return header


func _load_face_texture(face_path: String) -> Texture2D:
	if face_path.is_empty():
		return null
	return load(face_path) as Texture2D


## 分頁內容統一包一層 MarginContainer(TAB_CONTENT_PADDING)再放進 ScrollContainer,
## 避免文字/計量表貼齊分頁邊緣;分頁內容放不下時在 ScrollContainer 內部捲動,
## 不撐高外層固定尺寸的面板。
func _wrap_tab_content(tab_name: String, content: Control) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = tab_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# 引擎原生捲軸太粗、顏色也不搭羊皮紙底,換成 UiStyle 共用的淡色細版。
	UiStyle.apply_parchment_scrollbar(scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", TAB_CONTENT_PADDING)
	margin.add_theme_constant_override("margin_top", TAB_CONTENT_PADDING)
	margin.add_theme_constant_override("margin_right", TAB_CONTENT_PADDING)
	margin.add_theme_constant_override("margin_bottom", TAB_CONTENT_PADDING)
	scroll.add_child(margin)

	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(content)

	return scroll


## 「屬性」分頁:等級/武器/佔位形狀 + 六大素質 + 技能格。
func _build_attribute_tab() -> Control:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)

	var basic_title := Label.new()
	basic_title.text = "基本"
	basic_title.add_theme_font_size_override("font_size", 15)
	basic_title.add_theme_color_override("font_color", _title_color())
	column.add_child(basic_title)

	var info_row := HBoxContainer.new()
	info_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_row.add_theme_constant_override("separation", 16)
	column.add_child(info_row)

	var battle_cost_frame := PanelContainer.new()
	battle_cost_frame.custom_minimum_size = BATTLE_COST_FRAME_SIZE
	info_row.add_child(battle_cost_frame)

	var battle_cost_center := CenterContainer.new()
	battle_cost_frame.add_child(battle_cost_center)

	battle_cost_view = BattleCostView.new()
	battle_cost_view.cell_size = BATTLE_COST_CELL_SIZE
	battle_cost_center.add_child(battle_cost_view)

	var info_labels := VBoxContainer.new()
	info_labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_labels.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info_labels.add_theme_constant_override("separation", 8)
	info_row.add_child(info_labels)

	var level_row := _build_stat_row("等級")
	level_value_label = level_row["value_label"]
	info_labels.add_child(level_row["row"])

	var exp_row := _build_stat_row("EXP")
	exp_value_label = exp_row["value_label"]
	info_labels.add_child(exp_row["row"])

	exp_bar = ProgressBar.new()
	exp_bar.custom_minimum_size = Vector2(0, EXP_BAR_HEIGHT)
	exp_bar.show_percentage = false

	var exp_fill := StyleBoxFlat.new()
	exp_fill.bg_color = EXP_BAR_FILL
	exp_fill.set_corner_radius_all(int(EXP_BAR_HEIGHT / 2.0))
	exp_bar.add_theme_stylebox_override("fill", exp_fill)

	var exp_bg := StyleBoxFlat.new()
	exp_bg.bg_color = EXP_BAR_BG
	exp_bg.set_corner_radius_all(int(EXP_BAR_HEIGHT / 2.0))
	exp_bar.add_theme_stylebox_override("background", exp_bg)

	info_labels.add_child(exp_bar)

	## 「武器」這一列的數值直接用圖示表示(不再額外重複文字名稱),圖示本身的
	## tooltip_text(見 set_character())滑鼠停留可以看武器全名。跟 _build_stat_row()
	## 同樣是「標題靠左、數值靠右」的排版,只是數值換成圖示而不是文字 Label。
	var weapon_row := HBoxContainer.new()
	weapon_row.add_theme_constant_override("separation", 6)
	info_labels.add_child(weapon_row)

	var weapon_caption := Label.new()
	weapon_caption.text = "武器"
	weapon_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapon_caption.add_theme_font_size_override("font_size", 15)
	_apply_body_text_color(weapon_caption)
	weapon_row.add_child(weapon_caption)

	weapon_icon = TextureRect.new()
	weapon_icon.custom_minimum_size = WEAPON_ICON_SIZE
	weapon_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	weapon_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	weapon_row.add_child(weapon_icon)

	column.add_child(HSeparator.new())

	var potential_title := Label.new()
	potential_title.text = "素質"
	potential_title.add_theme_font_size_override("font_size", 15)
	potential_title.add_theme_color_override("font_color", _title_color())
	column.add_child(potential_title)

	var potential_grid := GridContainer.new()
	potential_grid.columns = 2
	potential_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	potential_grid.add_theme_constant_override("h_separation", 24)
	potential_grid.add_theme_constant_override("v_separation", 6)
	column.add_child(potential_grid)

	potential_value_labels.clear()
	for potential_type in POTENTIAL_GRID_ORDER:
		var stat_row := _build_stat_row(GameEnums.potential_label(potential_type))
		stat_row["row"].size_flags_horizontal = Control.SIZE_EXPAND_FILL
		potential_grid.add_child(stat_row["row"])
		potential_value_labels.append(stat_row["value_label"])

	column.add_child(HSeparator.new())

	var skill_title := Label.new()
	skill_title.text = "技能"
	skill_title.add_theme_font_size_override("font_size", 15)
	skill_title.add_theme_color_override("font_color", _title_color())
	column.add_child(skill_title)

	skill_row = GridContainer.new()
	skill_row.columns = SKILL_GRID_COLUMNS
	skill_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_row.add_theme_constant_override("h_separation", 8)
	skill_row.add_theme_constant_override("v_separation", 8)
	column.add_child(skill_row)

	return _wrap_tab_content("屬性", column)


## 「血統」分頁:潛力雷達圖 + 血統計量表 + 特性。
func _build_bloodline_tab() -> Control:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 6)

	var potential_title := Label.new()
	potential_title.text = "潛力"
	potential_title.add_theme_font_size_override("font_size", 15)
	potential_title.add_theme_color_override("font_color", _title_color())
	column.add_child(potential_title)

	radar = CharacterPotentialRadar.new()
	radar.custom_minimum_size = RADAR_MIN_SIZE
	radar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(radar)

	column.add_child(HSeparator.new())

	var bloodline_title := Label.new()
	bloodline_title.text = "血統"
	bloodline_title.add_theme_font_size_override("font_size", 15)
	bloodline_title.add_theme_color_override("font_color", _title_color())
	column.add_child(bloodline_title)

	bloodline_list = VBoxContainer.new()
	bloodline_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bloodline_list.add_theme_constant_override("separation", 6)
	column.add_child(bloodline_list)

	column.add_child(HSeparator.new())

	var trait_title := Label.new()
	trait_title.text = "特性"
	trait_title.add_theme_font_size_override("font_size", 15)
	trait_title.add_theme_color_override("font_color", _title_color())
	column.add_child(trait_title)

	trait_list = HFlowContainer.new()
	trait_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trait_list.add_theme_constant_override("h_separation", 8)
	trait_list.add_theme_constant_override("v_separation", 6)
	column.add_child(trait_list)

	return _wrap_tab_content("血統", column)


## 「家族」分頁:父母/配偶/孩子三個區塊,各自一行一個成員(小頭像 + 姓名/年齡/性別),
## 對照 Character.parent(0~2 筆)/mate(0~1 筆)/children(0~N 筆)。三個區塊的成員列表容器
## 在這裡建好存起來,實際內容在 _populate_family() 依角色資料動態填入。
func _build_family_tab() -> Control:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 6)

	var parent_title := Label.new()
	parent_title.text = "父母"
	parent_title.add_theme_font_size_override("font_size", 15)
	parent_title.add_theme_color_override("font_color", _title_color())
	column.add_child(parent_title)

	parent_list = VBoxContainer.new()
	parent_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent_list.add_theme_constant_override("separation", 6)
	column.add_child(parent_list)

	column.add_child(HSeparator.new())

	var mate_title := Label.new()
	mate_title.text = "配偶"
	mate_title.add_theme_font_size_override("font_size", 15)
	mate_title.add_theme_color_override("font_color", _title_color())
	column.add_child(mate_title)

	mate_list = VBoxContainer.new()
	mate_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mate_list.add_theme_constant_override("separation", 6)
	column.add_child(mate_list)

	column.add_child(HSeparator.new())

	var children_title := Label.new()
	children_title.text = "孩子"
	children_title.add_theme_font_size_override("font_size", 15)
	children_title.add_theme_color_override("font_color", _title_color())
	column.add_child(children_title)

	children_list = VBoxContainer.new()
	children_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	children_list.add_theme_constant_override("separation", 6)
	column.add_child(children_list)

	return _wrap_tab_content("家族", column)


## 力量等六大素質數值:有 battle_character(從戰鬥中點頭像開啟)時額外在括號附註套用完
## 暴擊/被動/buff/debuff 加成後的即時數值(例如「11 (14)」),取代原本畫在雷達圖上的
## 數字(見 CharacterPotentialRadar._draw_labels());沒有 battle_character 時只顯示基礎值。
func _update_potential_labels(character: Character, battle_character: BattleCharacter) -> void:
	for i in range(potential_value_labels.size()):
		var potential_type: int = POTENTIAL_GRID_ORDER[i]
		var base_value: int = roundi(character.get_potential(potential_type))
		if battle_character != null:
			var live_value: int = roundi(battle_character.get_potential(potential_type))
			potential_value_labels[i].text = "%d (%d)" % [base_value, live_value]
		else:
			potential_value_labels[i].text = "%d" % base_value


## 滿等(LevelSystem.is_max_level())時 exp_to_next_level() 回傳 0,計量表直接顯示滿條。
func _update_exp_bar(level_system: LevelSystem) -> void:
	if level_system.is_max_level():
		exp_bar.max_value = 1
		exp_bar.value = 1
		exp_value_label.text = "MAX"
		return

	var next_exp := level_system.exp_to_next_level()
	exp_bar.max_value = next_exp
	exp_bar.value = level_system.exp
	exp_value_label.text = "%d / %d" % [level_system.exp, next_exp]


## 技能格固定 4 格,角色技能不足 4 個時留空;技能綁定的武器跟目前手持武器不符時
## (Character.can_use_skill 判斷),整格反灰並在提示文字加註需要的武器,而不是直接不顯示——
## 玩家仍要看得到「學過這招,只是現在打不出來」。
func _populate_skills(character: Character) -> void:
	for child in skill_row.get_children():
		child.queue_free()

	var skill_list := character.skill_list
	for i in range(SKILL_SLOT_COUNT):
		var slot := PanelContainer.new()
		slot.custom_minimum_size = SKILL_SLOT_MIN_SIZE
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		slot.add_theme_stylebox_override("panel", UiStyle.bordered_panel(
			SKILL_SLOT_BG, SKILL_SLOT_BORDER, 2, 6
		))

		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		label.add_theme_font_size_override("font_size", 13)
		# 滑鼠停在格子上要顯示 slot.tooltip_text(技能說明),但 Label 蓋在
		# slot 上方預設會吃掉滑鼠事件,tooltip 判定抓到的是 Label(沒設
		# tooltip_text)而不是底下的 slot,導致完全不會彈出——這裡要讓
		# Label 忽略滑鼠事件,hover 才會穿透給 slot 本身判定。
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i < skill_list.size():
			var skill: Skill = skill_list[i]
			label.text = skill.name
			if character.can_use_skill(skill):
				slot.tooltip_text = skill.description
				slot.modulate = SKILL_ENABLED_MODULATE
			else:
				slot.tooltip_text = "%s\n（需裝備：%s）" % [skill.description, GameEnums.weapon_label(skill.bind_weapon)]
				slot.modulate = SKILL_DISABLED_MODULATE
		slot.add_child(label)

		skill_row.add_child(slot)


## 只列出非 0 的血統項目(通常 1~2 條,見 Bloodline.get_nonzero_entries()),
## 每條是「國家+階級」標籤(例如「獅血」「獅高血」)靠左、百分比靠右的兩端對齊列,
## 下面接一條計量表。只有高階血統(NOBLE)的文字才上國家代表色,平民血統(COMMON)
## 維持預設文字色,兩階級的視覺重要性才有區別。計量槽本身維持中性色、圓角(藥丸狀),
## 避免槽體本身的彩色跟文字顏色搶視覺。
func _populate_bloodline(bloodline: Bloodline) -> void:
	for child in bloodline_list.get_children():
		child.queue_free()

	if bloodline == null:
		return

	for entry in bloodline.get_nonzero_entries():
		var nation: int = entry["nation"]
		var rank: int = entry["rank"]
		var percentage: float = entry["percentage"]

		var entry_column := VBoxContainer.new()
		entry_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		entry_column.add_theme_constant_override("separation", 2)

		var stat_row := _build_stat_row(GameEnums.bloodline_full_label(nation, rank))
		stat_row["value_label"].text = "%.1f%%" % percentage
		if rank == GameEnums.BloodlineRank.NOBLE:
			var nation_color := GameEnums.bloodline_nation_color(nation)
			stat_row["caption_label"].add_theme_color_override("font_color", nation_color)
			stat_row["value_label"].add_theme_color_override("font_color", nation_color)
		entry_column.add_child(stat_row["row"])

		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, BLOODLINE_BAR_HEIGHT)
		bar.max_value = Bloodline.TOTAL
		bar.value = percentage
		bar.show_percentage = false

		var bar_fill := StyleBoxFlat.new()
		bar_fill.bg_color = BLOODLINE_BAR_FILL
		bar_fill.set_corner_radius_all(int(BLOODLINE_BAR_HEIGHT / 2.0))
		bar.add_theme_stylebox_override("fill", bar_fill)

		var bar_bg := StyleBoxFlat.new()
		bar_bg.bg_color = BLOODLINE_BAR_BG
		bar_bg.set_corner_radius_all(int(BLOODLINE_BAR_HEIGHT / 2.0))
		bar.add_theme_stylebox_override("background", bar_bg)

		entry_column.add_child(bar)
		bloodline_list.add_child(entry_column)


func _populate_traits(traits: Array[CharacterTrait]) -> void:
	for child in trait_list.get_children():
		child.queue_free()

	if traits.is_empty():
		var empty_label := Label.new()
		_apply_body_text_color(empty_label)
		trait_list.add_child(empty_label)
		return

	for character_trait in traits:
		var chip := PanelContainer.new()
		var color := _trait_color(character_trait.polarity)

		chip.add_theme_stylebox_override("panel", UiStyle.bordered_panel(
			Color(0.1, 0.1, 0.14, 0.6), color, 2, 10, 10.0, 4.0
		))
		chip.tooltip_text = character_trait.description

		var label := Label.new()
		label.text = character_trait.name
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", color)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(label)

		trait_list.add_child(chip)


## 家族三區塊(父母/配偶/孩子)共用同一套填入邏輯:清空舊列表 → 沒有成員時顯示
## 「（無）」→ 有成員則每人一行(_build_family_member_row())。
func _populate_family(character: Character) -> void:
	_populate_family_section(parent_list, character.parent)
	_populate_family_section(mate_list, [] if character.mate == null else [character.mate])
	_populate_family_section(children_list, character.children)


func _populate_family_section(list: VBoxContainer, members: Array) -> void:
	for child in list.get_children():
		child.queue_free()

	if members.is_empty():
		var empty_label := Label.new()
		_apply_body_text_color(empty_label)
		list.add_child(empty_label)
		return

	for member in members:
		list.add_child(_build_family_member_row(member as Character))


## 家族分頁一行一個成員:左邊小頭像、右邊姓名/年齡/性別三行(比照 _build_identity_header()
## 的排版語彙,只是頭像縮小、資訊欄改用較小字級)。
func _build_family_member_row(member: Character) -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)

	var portrait_frame := PanelContainer.new()
	portrait_frame.custom_minimum_size = FAMILY_PORTRAIT_SIZE
	portrait_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	portrait_frame.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	portrait_frame.gui_input.connect(_on_family_portrait_gui_input.bind(member))
	row.add_child(portrait_frame)

	var portrait_center := CenterContainer.new()
	portrait_frame.add_child(portrait_center)

	var portrait := TextureRect.new()
	portrait.custom_minimum_size = FAMILY_PORTRAIT_SIZE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_SCALE
	portrait.texture = _load_face_texture(member.face_path)
	portrait_center.add_child(portrait)

	var info_column := VBoxContainer.new()
	info_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info_column.add_theme_constant_override("separation", 4)
	row.add_child(info_column)

	var name_row := _build_stat_row("姓名")
	name_row["value_label"].text = member.full_name
	info_column.add_child(name_row["row"])

	var age_row := _build_stat_row("年齡")
	age_row["value_label"].text = "%d" % member.age
	info_column.add_child(age_row["row"])

	var status_row := _build_stat_row("狀態")
	status_row["value_label"].text = CharacterStatusRule.get_status_label(member)
	info_column.add_child(status_row["row"])

	var gender_row := _build_stat_row("性別")
	gender_row["value_label"].text = GameEnums.gender_symbol(member.gender)
	info_column.add_child(gender_row["row"])

	return row


## 點擊家族分頁的成員頭像:直接呼叫 CharacterPanel(autoload 單例)切換成該成員本人的
## 資料,跟戰場點頭像(battle_party_roster.gd 的 _on_portrait_gui_input())同一套慣例。
## CharacterPanel 只有一個彈出面板,呼叫 open_for_character() 會直接原地覆蓋成新角色,
## 不會疊出第二層面板,也因此不需要額外處理「返回上一位」。
func _on_family_portrait_gui_input(input_event: InputEvent, member: Character) -> void:
	if input_event is InputEventMouseButton and input_event.pressed and input_event.button_index == MOUSE_BUTTON_LEFT:
		CharacterPanel.open_for_character(member)


func _trait_color(polarity: int) -> Color:
	match polarity:
		GameEnums.TraitPolarity.POSITIVE:
			return TRAIT_COLOR_POSITIVE
		GameEnums.TraitPolarity.NEGATIVE:
			return TRAIT_COLOR_NEGATIVE
		_:
			return TRAIT_COLOR_NEUTRAL
