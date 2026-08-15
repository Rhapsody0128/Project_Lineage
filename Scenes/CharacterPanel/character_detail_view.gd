class_name CharacterDetailView
extends HBoxContainer

# =========================================================
# 角色詳細資訊的橫向排版元件:左側頭像/姓名/基本資料/佔位形狀,
# 中間潛力雷達圖,右側技能/特質——三欄併排。CharacterPanel(彈出式
# 角色面板)也改成內嵌這顆元件,兩處共用同一份資料呈現邏輯,
# 不再各自維護一份。程式化建構節點,比照 HeaderBar/HeroCard 等
# 既有共用元件的慣例,不另外拆 .tscn。
#
# 直接繼承 HBoxContainer(而不是包一層 Control 手動 anchor 滿版的
# HBoxContainer)才能讓最小高度正確從三欄內容往上回報給
# CharacterPanel/CharacterRoster 的外層容器——包一層普通 Control
# 對子節點用滿版 anchor 時,Control 本身的 get_minimum_size() 不會
# 跟著子節點內容變動,回報永遠是 0,外層容器就會把這顆元件硬壓在
# 固定/不夠高的空間裡,內容被擠到超出邊界(見角色列表畫面文字跑版
# 的 bug)。
#
# 用法:var view := CharacterDetailView.new(); parent.add_child(view);
# view.set_hero(hero, battle_hero)。battle_hero 選填,語意跟
# CharacterPotentialRadar.set_hero() 一致(戰場即時數值)。
# =========================================================

## 技能格 2*2 排列(原本 1*4 太寬,彈出式 CharacterPanel 固定寬度會被撐破,
## 見 Battle 場景截圖回報),GridContainer columns=2。
const SKILL_SLOT_COUNT := 4
const SKILL_GRID_COLUMNS := 2
const SKILL_SLOT_MIN_SIZE := Vector2(130, 44)
const AVATAR_SIZE := Vector2(96, 96)
const BATTLE_COST_FRAME_SIZE := Vector2(96, 96)
const BATTLE_COST_CELL_SIZE := 16.0
const RADAR_MIN_SIZE := Vector2(240, 170)
const IDENTITY_COLUMN_WIDTH := 220.0

const TITLE_COLOR := Color(0.95, 0.9, 0.72, 1)
const FRAME_BG := Color(0.08, 0.08, 0.1, 0.6)
const SKILL_SLOT_BG := Color(0.1, 0.1, 0.14, 0.6)
const SKILL_SLOT_BORDER := Color(0.4, 0.46, 0.66, 1)

const TRAIT_COLOR_POSITIVE := Color(0.55, 0.85, 0.55)
const TRAIT_COLOR_NEGATIVE := Color(0.9, 0.5, 0.5)
const TRAIT_COLOR_NEUTRAL := Color(0.8, 0.8, 0.8)

## 技能綁定的武器跟目前手持武器不符時,整格反灰(半透明)提示無法施放
const SKILL_DISABLED_MODULATE := Color(1, 1, 1, 0.4)
const SKILL_ENABLED_MODULATE := Color(1, 1, 1, 1)

var avatar_texture: TextureRect
var full_name_label: Label
var age_label: Label
var level_label: Label
var weapon_label: Label
var battle_cost_view: BattleCostView
var radar: CharacterPotentialRadar
var skill_row: GridContainer
var trait_list: HFlowContainer


func _ready() -> void:
	add_theme_constant_override("separation", 24)

	add_child(_build_identity_column())
	add_child(_build_radar_column())
	add_child(_build_skill_trait_column())


## 任何場景都可呼叫:view.set_hero(hero, battle_hero)。傳 null 代表清空
## (面板關閉/離開角色列表選取時停止雷達圖逐幀重繪,見 CharacterPotentialRadar)。
func set_hero(hero: Hero, battle_hero: BattleHero = null) -> void:
	if hero == null:
		radar.set_hero(null)
		return

	full_name_label.text = hero.full_name
	age_label.text = "年齡：%d" % hero.age
	level_label.text = "等級：%d" % hero.level_system.level
	weapon_label.text = "武器：%s" % GameEnums.weapon_label(hero.weapon)
	avatar_texture.texture = _load_face_texture(hero.face_path)

	var is_leader := battle_hero != null and battle_hero.is_leader
	var is_enemy := battle_hero != null and battle_hero.is_enemy

	battle_cost_view.weapon = hero.weapon
	battle_cost_view.is_leader = is_leader
	battle_cost_view.is_enemy = is_enemy
	battle_cost_view.battle_cost = hero.battle_cost

	radar.set_hero(hero, battle_hero)

	_populate_skills(hero)
	_populate_traits(hero.traits)


func _build_identity_column() -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(IDENTITY_COLUMN_WIDTH, 0)
	column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_theme_constant_override("separation", 6)

	var avatar_row := HBoxContainer.new()
	avatar_row.alignment = BoxContainer.ALIGNMENT_CENTER
	avatar_row.add_theme_constant_override("separation", 10)
	column.add_child(avatar_row)

	var avatar_frame := PanelContainer.new()
	avatar_frame.custom_minimum_size = AVATAR_SIZE
	avatar_row.add_child(avatar_frame)

	avatar_texture = TextureRect.new()
	avatar_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar_texture.stretch_mode = TextureRect.STRETCH_SCALE
	avatar_frame.add_child(avatar_texture)

	var battle_cost_frame := PanelContainer.new()
	battle_cost_frame.custom_minimum_size = BATTLE_COST_FRAME_SIZE
	avatar_row.add_child(battle_cost_frame)

	var battle_cost_center := CenterContainer.new()
	battle_cost_frame.add_child(battle_cost_center)

	battle_cost_view = BattleCostView.new()
	battle_cost_view.cell_size = BATTLE_COST_CELL_SIZE
	battle_cost_center.add_child(battle_cost_view)

	full_name_label = Label.new()
	full_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	full_name_label.add_theme_font_size_override("font_size", 18)
	column.add_child(full_name_label)

	age_label = Label.new()
	age_label.text = "年齡：--"
	age_label.add_theme_font_size_override("font_size", 15)
	column.add_child(age_label)

	level_label = Label.new()
	level_label.text = "等級：--"
	level_label.add_theme_font_size_override("font_size", 15)
	column.add_child(level_label)

	weapon_label = Label.new()
	weapon_label.text = "武器：--"
	weapon_label.add_theme_font_size_override("font_size", 15)
	column.add_child(weapon_label)

	return column


func _build_radar_column() -> Control:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.custom_minimum_size = RADAR_MIN_SIZE
	column.add_theme_constant_override("separation", 4)

	var title := Label.new()
	title.text = "潛力"
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	column.add_child(title)

	radar = CharacterPotentialRadar.new()
	radar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	radar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(radar)

	return column


func _build_skill_trait_column() -> Control:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 4)

	var skill_title := Label.new()
	skill_title.text = "技能"
	skill_title.add_theme_font_size_override("font_size", 15)
	skill_title.add_theme_color_override("font_color", TITLE_COLOR)
	column.add_child(skill_title)

	skill_row = GridContainer.new()
	skill_row.columns = SKILL_GRID_COLUMNS
	skill_row.add_theme_constant_override("h_separation", 8)
	skill_row.add_theme_constant_override("v_separation", 8)
	column.add_child(skill_row)

	var trait_title := Label.new()
	trait_title.text = "特質"
	trait_title.add_theme_font_size_override("font_size", 15)
	trait_title.add_theme_color_override("font_color", TITLE_COLOR)
	column.add_child(trait_title)

	trait_list = HFlowContainer.new()
	trait_list.add_theme_constant_override("h_separation", 8)
	trait_list.add_theme_constant_override("v_separation", 6)
	column.add_child(trait_list)

	return column


func _load_face_texture(face_path: String) -> Texture2D:
	if face_path.is_empty():
		return null
	return load(face_path) as Texture2D


## 技能格固定 4 格,角色技能不足 4 個時留空;技能綁定的武器跟目前手持武器不符時
## (Hero.can_use_skill 判斷),整格反灰並在提示文字加註需要的武器,而不是直接不顯示——
## 玩家仍要看得到「學過這招,只是現在打不出來」。
func _populate_skills(hero: Hero) -> void:
	for child in skill_row.get_children():
		child.queue_free()

	var skill_list := hero.skill_list
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
			if hero.can_use_skill(skill):
				slot.tooltip_text = skill.description
				slot.modulate = SKILL_ENABLED_MODULATE
			else:
				slot.tooltip_text = "%s\n（需裝備：%s）" % [skill.description, GameEnums.weapon_label(skill.bind_weapon)]
				slot.modulate = SKILL_DISABLED_MODULATE
		slot.add_child(label)

		skill_row.add_child(slot)


func _populate_traits(traits: Array[CharacterTrait]) -> void:
	for child in trait_list.get_children():
		child.queue_free()

	if traits.is_empty():
		var empty_label := Label.new()
		empty_label.text = "（無特質）"
		empty_label.add_theme_font_size_override("font_size", 13)
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


func _trait_color(polarity: int) -> Color:
	match polarity:
		GameEnums.TraitPolarity.POSITIVE:
			return TRAIT_COLOR_POSITIVE
		GameEnums.TraitPolarity.NEGATIVE:
			return TRAIT_COLOR_NEGATIVE
		_:
			return TRAIT_COLOR_NEUTRAL
