class_name FamilyTree
extends Control

# =========================================================
# 祖譜畫面殼:背景/標題/返回鍵在 .tscn 固定排版,樹狀圖本身(FamilyTreeCanvas)
# 節點數量隨家族大小變動,程式化建構、放進 ScrollContainer 捲動。
#
# 入口:CharacterDetailView 家族分頁「觀看祖譜」按鈕、CharacterRoster 左側面板
# 的「觀看祖譜」按鈕(見該檔案 _on_view_family_tree_pressed())都呼叫
# SceneHandoffStore.queue(FamilyTree.FOCUS_MAILBOX_KEY, character) 再切場景過來,
# 這裡用 take() 一次性讀出——不是 Dialogue 那種需要撐住 lambda 生命週期的用途,
# 讀完即可清空。
#
# 頂部橫幅(FamilyBanner,.tscn 固定位置,子節點程式化建構):家族徽章(圖片來自
# Images/FamilyBanner/,依姓氏決定,見 UiStyle.family_banner_path())+「OO家族」標題 +
# 最高家族階級 + 總成員(還在世/全部)+ 主血統,走 FamilyTreeBuilder.build() 統計整個
# 祖譜連通圖(含不在小隊裡的配偶),跟 CharacterDetailView 家族分頁的家族旗幟區塊共用
# 同一套規則層計算。
# =========================================================

## SceneHandoffStore 的 key,呼叫端跟這裡共用同一個常數存取,不要各自硬編字串。
const FOCUS_MAILBOX_KEY := "family_tree_focus"

## 正方形徽章,跟 CharacterDetailView.FAMILY_FLAG_SIZE 同尺寸。
const BANNER_FLAG_SIZE := Vector2(140, 140)
const BANNER_TEXT_COLOR := Color(0.95, 0.9, 0.72, 1)

@onready var canvas: FamilyTreeCanvas = $ScrollContainer/Canvas
@onready var back_button: Button = $TopBar/BackButton
@onready var banner: HBoxContainer = $FamilyBanner


func _ready() -> void:
	UiStyle.apply_wood_plaque_button(back_button, 16.0, 8.0)
	back_button.add_theme_font_size_override("font_size", 18)

	var handoff := SceneHandoffStore.take(FOCUS_MAILBOX_KEY)
	var focus_character: Character = handoff.payload as Character if handoff != null else null
	if focus_character != null:
		canvas.render(focus_character)
		_populate_banner(focus_character)


## 家族徽章(正方形貼圖,見 UiStyle.family_banner_path())+「OO家族」標題 +
## 最高家族階級/總成員/主血統三行,統計走 FamilyTreeBuilder.build()
## (見 System/family_tree/family_tree_builder.gd)。
func _populate_banner(focus_character: Character) -> void:
	for child in banner.get_children():
		child.queue_free()

	var flag := TextureRect.new()
	flag.custom_minimum_size = BANNER_FLAG_SIZE
	flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	flag.texture = load(UiStyle.family_banner_path(focus_character.last_name))
	banner.add_child(flag)

	var info_column := VBoxContainer.new()
	info_column.add_theme_constant_override("separation", 4)
	banner.add_child(info_column)

	var last_name := focus_character.last_name if not focus_character.last_name.is_empty() else "（無姓氏）"
	var family_name_label := Label.new()
	family_name_label.text = "%s家族" % last_name
	family_name_label.add_theme_font_size_override("font_size", 22)
	family_name_label.add_theme_color_override("font_color", BANNER_TEXT_COLOR)
	info_column.add_child(family_name_label)

	var units := FamilyTreeBuilder.build(focus_character)

	## 「世家」是稱謂後綴,跟 NobleTitleRule.label_for_rank() 本身的稱號字串串接,
	## 不是稱號表裡的一員。
	var rank_label := "%s世家" % NobleTitleRule.label_for_rank(FamilyTreeBuilder.highest_title_rank(units))
	info_column.add_child(_build_banner_row("最高家族階級", rank_label))

	var alive_count := FamilyTreeBuilder.count_alive_members(units)
	var total_count := FamilyTreeBuilder.count_members(units)
	info_column.add_child(_build_banner_row("總成員", "%d / %d" % [alive_count, total_count]))

	var bloodline_label := FamilyTreeBuilder.dominant_bloodline_label(units)
	if not bloodline_label.is_empty():
		info_column.add_child(_build_banner_row("主血統", bloodline_label))


func _build_banner_row(caption: String, value: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var caption_label := Label.new()
	caption_label.text = caption
	caption_label.add_theme_font_size_override("font_size", 16)
	caption_label.add_theme_color_override("font_color", BANNER_TEXT_COLOR)
	row.add_child(caption_label)

	var value_label := Label.new()
	value_label.text = value
	value_label.add_theme_font_size_override("font_size", 16)
	value_label.add_theme_color_override("font_color", BANNER_TEXT_COLOR)
	row.add_child(value_label)

	return row


func _on_back_pressed() -> void:
	NavigationStore.go_back()
