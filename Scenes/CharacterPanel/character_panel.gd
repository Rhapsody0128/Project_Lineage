extends CanvasLayer

# =========================================================
# 全域共用的角色資料面板(以 autoload 掛載於 project.godot,
# 任何場景呼叫 CharacterPanel.open_for_hero(hero) 即可彈出,
# 不屬於任何單一場景;右上角叉叉鍵關閉)。
# 只負責把 Hero 的資料轉成畫面呈現,不含遊戲邏輯判定。
# =========================================================

# 角色小人暫用 Warrier 站立圖片(idle_Down 第一幀)佔位
const STANDEE_ATLAS_PATH := "res://Images/Warrier/character_walk.png"
const STANDEE_REGION := Rect2(0, 0, 32, 46)

const SKILL_SLOT_COUNT := 4
const SKILL_SLOT_MIN_SIZE := Vector2(150, 56)

const TRAIT_COLOR_POSITIVE := Color(0.55, 0.85, 0.55)
const TRAIT_COLOR_NEGATIVE := Color(0.9, 0.5, 0.5)
const TRAIT_COLOR_NEUTRAL := Color(0.8, 0.8, 0.8)

@onready var root: Control = $Root
@onready var avatar_texture: TextureRect = $Root/CenterContainer/PanelBox/Margin/Content/HeaderRow/LeftHeader/AvatarFrame/AvatarTexture
@onready var full_name_label: Label = $Root/CenterContainer/PanelBox/Margin/Content/HeaderRow/LeftHeader/FullNameLabel
@onready var age_label: Label = $Root/CenterContainer/PanelBox/Margin/Content/HeaderRow/RightHeader/StatsRow/AgeLabel
@onready var level_label: Label = $Root/CenterContainer/PanelBox/Margin/Content/HeaderRow/RightHeader/StatsRow/LevelLabel
@onready var standee_texture: TextureRect = $Root/CenterContainer/PanelBox/Margin/Content/HeaderRow/RightHeader/StandeeFrame/StandeeTexture
@onready var radar: CharacterPotentialRadar = $Root/CenterContainer/PanelBox/Margin/Content/RadarSection/PotentialRadar
@onready var skill_row: HBoxContainer = $Root/CenterContainer/PanelBox/Margin/Content/SkillSection/SkillRow
@onready var trait_list: HFlowContainer = $Root/CenterContainer/PanelBox/Margin/Content/TraitSection/TraitList

var _standee_atlas: Texture2D


func _ready() -> void:
	root.visible = false
	_standee_atlas = load(STANDEE_ATLAS_PATH)


## 任何場景都可呼叫:CharacterPanel.open_for_hero(hero)
func open_for_hero(hero: Hero) -> void:
	if hero == null:
		return

	full_name_label.text = hero.full_name
	age_label.text = "年齡：%d" % hero.age
	level_label.text = "等級：%d" % hero.level_system.level
	avatar_texture.texture = _load_face_texture(hero.face_path)
	standee_texture.texture = _build_standee_texture()

	radar.set_hero(hero)

	_populate_skills(hero.skill_list)
	_populate_traits(hero.traits)

	root.visible = true


func close() -> void:
	root.visible = false


func _load_face_texture(face_path: String) -> Texture2D:
	if face_path.is_empty():
		return null
	return load(face_path) as Texture2D


func _build_standee_texture() -> Texture2D:
	var standee := AtlasTexture.new()
	standee.atlas = _standee_atlas
	standee.region = STANDEE_REGION
	return standee


## 技能格固定 4 格,角色技能不足 4 個時留空
func _populate_skills(skill_list: Array[Skill]) -> void:
	for child in skill_row.get_children():
		child.queue_free()

	for i in range(SKILL_SLOT_COUNT):
		var slot := PanelContainer.new()
		slot.custom_minimum_size = SKILL_SLOT_MIN_SIZE
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.14, 0.6)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.4, 0.46, 0.66, 1)
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_right = 6
		style.corner_radius_bottom_left = 6
		slot.add_theme_stylebox_override("panel", style)

		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		if i < skill_list.size():
			label.text = skill_list[i].name
			slot.tooltip_text = skill_list[i].description
		slot.add_child(label)

		skill_row.add_child(slot)


func _populate_traits(traits: Array[CharacterTrait]) -> void:
	for child in trait_list.get_children():
		child.queue_free()

	if traits.is_empty():
		var empty_label := Label.new()
		empty_label.text = "（無特質）"
		trait_list.add_child(empty_label)
		return

	for character_trait in traits:
		var chip := PanelContainer.new()
		var color := _trait_color(character_trait.polarity)

		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.14, 0.6)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = color
		style.corner_radius_top_left = 10
		style.corner_radius_top_right = 10
		style.corner_radius_bottom_right = 10
		style.corner_radius_bottom_left = 10
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		chip.add_theme_stylebox_override("panel", style)
		chip.tooltip_text = character_trait.description

		var label := Label.new()
		label.text = character_trait.name
		label.add_theme_color_override("font_color", color)
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
