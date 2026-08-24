extends Control

# =========================================================
# 戰報統計:從戰報列表按「戰報」進來,顯示 BattleReportStore.pending_stats_report 這場
# 戰鬥的統計面板——不重播戰場畫面,單純呈現數字。上半是雙方每個角色的血量變化
# (開戰血量 ＞ 戰鬥後血量),下半是戰鬥結果統計表(見 BattleReportStats)。
#
# 跟戰報列表一樣,整份內容用程式碼動態產生,不另外拆 row 子場景。
# =========================================================

const AVATAR_SIZE := Vector2(44, 44)
const WIN_COLOR := Color(0.1, 0.9, 0.1)
const LOSE_COLOR := Color(0.9, 0.1, 0.1)
const DRAW_COLOR := Color(0.0, 0.0, 0.0)
const NEUTRAL_COLOR := UiStyle.PARCHMENT_TEXT_COLOR

const FALLBACK_PORTRAIT_ATLAS_PATH := "res://Images/Warrier/character_walk.png"
const FALLBACK_PORTRAIT_REGION := Rect2(0, 0, 32, 46)

@onready var main_panel: PanelContainer = $MainPanel
@onready var self_hp_list: VBoxContainer = $MainPanel/Margin/VBox/ScrollContainer/Content/HpSection/SelfColumn/SelfHpList
@onready var enemy_hp_list: VBoxContainer = $MainPanel/Margin/VBox/ScrollContainer/Content/HpSection/EnemyColumn/EnemyHpList
@onready var stats_table: VBoxContainer = $MainPanel/Margin/VBox/ScrollContainer/Content/StatsTable
@onready var back_button: Button = $TopBar/BackButton

var _fallback_portrait: Texture2D


func _ready() -> void:
	UiStyle.apply_wood_plaque_button(back_button, 30.0, 10.0)
	back_button.add_theme_font_size_override("font_size", 16)
	UiStyle.apply_parchment_panel(main_panel, 1320.0, 740.0)

	var report := BattleReportStore.pending_stats_report
	if report == null:
		NavigationStore.go_back()
		return

	_fallback_portrait = AtlasTexture.new()
	_fallback_portrait.atlas = load(FALLBACK_PORTRAIT_ATLAS_PATH)
	_fallback_portrait.region = FALLBACK_PORTRAIT_REGION

	var stats := BattleReportStats.new(report.battle)
	_populate_hp_list(self_hp_list, stats.self_character_rows)
	_populate_hp_list(enemy_hp_list, stats.enemy_character_rows)
	_populate_stats_table(stats)


func _populate_hp_list(list: VBoxContainer, rows: Array[Dictionary]) -> void:
	for row in rows:
		list.add_child(_build_hp_row(row))


func _build_hp_row(row: Dictionary) -> Control:
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 10)

	var portrait := TextureRect.new()
	portrait.custom_minimum_size = AVATAR_SIZE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_SCALE
	portrait.texture = _load_portrait(row.face_path)
	content.add_child(portrait)

	var name_label := Label.new()
	name_label.text = row.name
	name_label.custom_minimum_size = Vector2(100, 0)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	content.add_child(name_label)

	var hp_label := Label.new()
	hp_label.text = "%d ＞ %d" % [row.start_hp, row.end_hp]
	hp_label.add_theme_font_size_override("font_size", 15)
	hp_label.add_theme_color_override("font_color", _hp_change_color(row.start_hp, row.end_hp))
	content.add_child(hp_label)

	return content


func _hp_change_color(start_hp: int, end_hp: int) -> Color:
	if end_hp <= 0:
		return LOSE_COLOR
	if end_hp < start_hp:
		return DRAW_COLOR
	return WIN_COLOR


func _load_portrait(face_path: String) -> Texture2D:
	if face_path.is_empty():
		return _fallback_portrait
	var texture := load(face_path) as Texture2D
	return texture if texture != null else _fallback_portrait


func _populate_stats_table(stats: BattleReportStats) -> void:
	_add_stat_row("戰鬥結果", stats.result_text, _result_color(stats.result))
	_add_stat_row("使用回合數", str(stats.rounds_used))
	_add_stat_row("勝敗原因", stats.end_reason_text)
	_add_stat_row("最高傷害(記錄輸出)", _top_text(stats.top_damage_name, stats.top_damage_value))
	_add_stat_row("最高防衛(紀錄守備類技能)", _top_text(stats.top_guard_name, stats.top_guard_value))
	_add_stat_row("最高技能施放(紀錄SKILL施放次數)", _top_text(stats.top_skill_name, stats.top_skill_value))
	_add_stat_row("奧義使用次數", str(stats.ultimate_use_count))


func _top_text(character_name: String, value: int) -> String:
	if character_name.is_empty():
		return "無"
	return "%s（%d）" % [character_name, value]


func _result_color(result: GameEnums.BattleResultType) -> Color:
	match result:
		GameEnums.BattleResultType.SELF_WIN:
			return WIN_COLOR
		GameEnums.BattleResultType.ENEMY_WIN:
			return LOSE_COLOR
		_:
			return DRAW_COLOR


func _add_stat_row(label_text: String, value_text: String, value_color: Color = NEUTRAL_COLOR) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(260, 0)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	row.add_child(label)

	var value_label := Label.new()
	value_label.text = value_text
	value_label.add_theme_font_size_override("font_size", 16)
	value_label.add_theme_color_override("font_color", value_color)
	row.add_child(value_label)

	stats_table.add_child(row)


func _on_back_pressed() -> void:
	BattleReportStore.pending_stats_report = null
	if BattleReportStore.pending_stats_continuation.is_valid():
		var continuation := BattleReportStore.pending_stats_continuation
		BattleReportStore.pending_stats_continuation = Callable()
		continuation.call()
		return
	NavigationStore.go_back()
