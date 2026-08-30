class_name TechTree
extends Control

# =========================================================
# 科技樹畫面殼:比照 Scenes/FamilyTree/family_tree.gd 的寫法——獨立場景(NavigationStore.
# go_to()/go_back() 切換,不是 ActionPanel 疊加),背景/標題/返回鍵固定排版在 .tscn,
# 樹狀圖本身(TechTreeCanvas)程式化建構、放進 ScrollContainer 捲動。沒有 HeaderBar,
# 世界時間依既有慣例自動停止推進(比照祖譜/新生兒命名畫面)。
#
# 入口:Scenes/Base/base_action_panel.gd 的 _open_tech_tree_panel()——呼叫前會先
# ActionPanel.close(false) 關掉科學研究所的 ActionPanel(避免那層 CanvasLayer 疊在這個
# 新場景上面),再 NavigationStore.go_to() 過來。返回鍵改用 SceneHandoffStore 交接
# 「要重開哪一棟建築的 ActionPanel」給 Base 場景(見 REOPEN_BUILDING_MAILBOX_KEY),
# Scenes/Base/base_inner.gd._ready() 讀出來後呼叫 BaseBuildingEvent.open_action_panel()
# 還原成「依然在科學研究所」的畫面。
# =========================================================

## SceneHandoffStore 的 key,呼叫端(這裡的返回鍵)跟接收端(base_inner.gd)共用同一個
## 常數存取,不要各自硬編字串。payload 是 GameEnums.BuildingType(int)。
const REOPEN_BUILDING_MAILBOX_KEY := "tech_tree_reopen_building_type"

const BRANCH_ORDER: Array[GameEnums.TechBranch] = [
	GameEnums.TechBranch.COMBAT,
	GameEnums.TechBranch.DOMESTIC,
	GameEnums.TechBranch.KNOWLEDGE,
]
const BRANCH_LABELS := {
	GameEnums.TechBranch.COMBAT: "戰鬥",
	GameEnums.TechBranch.DOMESTIC: "內政",
	GameEnums.TechBranch.KNOWLEDGE: "知識",
}

@onready var canvas: TechTreeCanvas = $ScrollContainer/Canvas
@onready var top_bar: HBoxContainer = $TopBar
@onready var back_button: Button = $TopBar/BackButton

var _tab_buttons: Dictionary = {}
var _research_label: Label


func _ready() -> void:
	UiStyle.apply_wood_plaque_button(back_button, 16.0, 8.0)
	back_button.add_theme_font_size_override("font_size", 18)
	back_button.pressed.connect(_on_back_pressed)

	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 8)
	for branch in BRANCH_ORDER:
		var button := Button.new()
		button.text = BRANCH_LABELS[branch]
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(90, 46)
		UiStyle.apply_wood_plaque_button(button, 16.0, 8.0)
		button.pressed.connect(_select_branch.bind(branch))
		tab_row.add_child(button)
		_tab_buttons[branch] = button
	top_bar.add_child(tab_row)
	top_bar.move_child(tab_row, 0)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)
	top_bar.move_child(spacer, back_button.get_index())

	var research_chip := _build_research_chip()
	top_bar.add_child(research_chip)
	top_bar.move_child(research_chip, back_button.get_index())

	BaseResourceStore.changed.connect(_refresh_research_label)
	_refresh_research_label()
	_select_branch(GameEnums.TechBranch.COMBAT)


func _build_research_chip() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(28, 28)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = load(GameEnums.resource_type_icon_path(GameEnums.ResourceType.RESEARCH)) as Texture2D
	row.add_child(icon)

	_research_label = Label.new()
	_research_label.add_theme_font_size_override("font_size", 20)
	_research_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.72, 1))
	row.add_child(_research_label)

	return row


func _refresh_research_label() -> void:
	_research_label.text = str(BaseResourceStore.get_display_amount(GameEnums.ResourceType.RESEARCH))


func _select_branch(branch: GameEnums.TechBranch) -> void:
	for branch_key in _tab_buttons:
		var button: Button = _tab_buttons[branch_key]
		button.button_pressed = branch_key == branch
	canvas.render(branch)


func _on_back_pressed() -> void:
	SceneHandoffStore.queue(REOPEN_BUILDING_MAILBOX_KEY, GameEnums.BuildingType.RESEARCH_INSTITUTE)
	NavigationStore.go_back()
