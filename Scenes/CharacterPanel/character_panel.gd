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

## 技能綁定的武器跟目前手持武器不符時,整格反灰(半透明)提示無法施放
const SKILL_DISABLED_MODULATE := Color(1, 1, 1, 0.4)
const SKILL_ENABLED_MODULATE := Color(1, 1, 1, 1)

@onready var root: Control = $Root
@onready var avatar_texture: TextureRect = $Root/CenterContainer/PanelBox/Margin/Content/HeaderRow/LeftHeader/AvatarFrame/AvatarTexture
@onready var full_name_label: Label = $Root/CenterContainer/PanelBox/Margin/Content/HeaderRow/LeftHeader/FullNameLabel
@onready var age_label: Label = $Root/CenterContainer/PanelBox/Margin/Content/HeaderRow/RightHeader/StatsRow/AgeLabel
@onready var level_label: Label = $Root/CenterContainer/PanelBox/Margin/Content/HeaderRow/RightHeader/StatsRow/LevelLabel
@onready var weapon_label: Label = $Root/CenterContainer/PanelBox/Margin/Content/HeaderRow/RightHeader/StatsRow/WeaponLabel
@onready var standee_texture: TextureRect = $Root/CenterContainer/PanelBox/Margin/Content/HeaderRow/RightHeader/StandeeFrame/StandeeTexture
@onready var radar: CharacterPotentialRadar = $Root/CenterContainer/PanelBox/Margin/Content/RadarSection/PotentialRadar
@onready var skill_row: HBoxContainer = $Root/CenterContainer/PanelBox/Margin/Content/SkillSection/SkillRow
@onready var trait_list: HFlowContainer = $Root/CenterContainer/PanelBox/Margin/Content/TraitSection/TraitList

var _standee_atlas: Texture2D


func _ready() -> void:
	root.visible = false
	_standee_atlas = load(STANDEE_ATLAS_PATH)


## 任何場景都可呼叫:CharacterPanel.open_for_hero(hero)。battle_hero 是選填的
## ——從戰鬥場景點頭像開啟時會多帶這個(見 battle_party_roster.gd),讓雷達圖能
## 額外顯示套用完戰場加成(暴擊/被動/buff/debuff)的即時數值,且隨戰況連動更新;
## 非戰鬥情境(創角面板等)留空即可,雷達圖只顯示基礎潛力數字。
func open_for_hero(hero: Hero, battle_hero: BattleHero = null) -> void:
	if hero == null:
		return

	full_name_label.text = hero.full_name
	age_label.text = "年齡：%d" % hero.age
	level_label.text = "等級：%d" % hero.level_system.level
	weapon_label.text = "武器：%s" % GameEnums.weapon_label(hero.weapon)
	avatar_texture.texture = _load_face_texture(hero.face_path)
	standee_texture.texture = _build_standee_texture()

	radar.set_hero(hero, battle_hero)

	_populate_skills(hero)
	_populate_traits(hero.traits)

	root.visible = true


func close() -> void:
	root.visible = false
	# 面板關閉後停止雷達圖的逐幀重繪(見 CharacterPotentialRadar._process()),
	# 不然戰鬥中即使面板關著,還是會白白每幀重繪一個沒人在看的節點。
	radar.set_hero(null)


func _load_face_texture(face_path: String) -> Texture2D:
	if face_path.is_empty():
		return null
	return load(face_path) as Texture2D


func _build_standee_texture() -> Texture2D:
	var standee := AtlasTexture.new()
	standee.atlas = _standee_atlas
	standee.region = STANDEE_REGION
	return standee


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
			Color(0.1, 0.1, 0.14, 0.6), Color(0.4, 0.46, 0.66, 1), 2, 6
		))

		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
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
