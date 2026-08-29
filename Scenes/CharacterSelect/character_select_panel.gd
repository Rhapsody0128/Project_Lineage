class_name CharacterSelectPanel
extends HBoxContainer

# =========================================================
# 根據地各建築「選一位角色」情境共用的選人畫面——呼叫端(見 Scenes/Base/
# base_action_panel.gd 的 _open_dispatch_picker() 等)塞進
# Scenes/CharacterSelect/character_select_overlay.gd 的 CharacterSelectOverlay 顯示,
# 疊加在目前畫面最上層,不是取代/關閉底下的面板。
#
# 版面三塊:左側 CharacterDetailView 顯示目前聚焦角色的完整情報(素質/血統/家族全分頁,
# 跟 CharacterPanel/CharacterRoster 共用同一顆元件)——寬度是這顆元件自己攜帶的
# PANEL_WIDTH,這裡不用也不該再設一次,右邊畫一條線分隔右欄,不套羊皮紙面板(比照
# marriage_proposal_panel.gd 的既有慣例);右上 context_box 是彈性空間,呼叫端依情境自行
# 塞說明文字/額外資訊,不需要就留空;右下 CharacterSelectBar 是排序/篩選 + 卡片網格
# (card_factory 一律回傳 CharacterAvatarCard,完整素質已經在左側,卡片只需要負責
# 「選中/不可選」,見該檔案的 available/unavailable_reason)。整包內容自然往下長,
# 超出的部分交給外層 CharacterSelectOverlay 唯一的捲動框處理(見該檔案開頭註解)。
#
# 點卡片只是換左側聚焦顯示(_on_card_selected),不會立刻觸發呼叫端的動作——一定要按
# 下方確認鈕才會 emit character_confirmed,讓玩家能先翻過幾張卡片看完整資料再決定,
# 不是點下去立刻指派/開始訓練,選錯只能取消重來。取消鈕/疊加面板的 × 鈕都算放棄,由
# CharacterSelectOverlay 接 cancelled 訊號處理(直接關掉疊加面板,底下的面板不受影響)。
#
# 用法:先 add_child() 掛進場景樹,再呼叫 setup()——跟 CharacterSelectBar 同一套慣例。
# =========================================================

signal character_confirmed(character: Character)
signal cancelled()

const DEFAULT_CONFIRM_LABEL := "確認選擇"

var context_box: VBoxContainer

var _detail_view: CharacterDetailView
var _select_bar: CharacterSelectBar
var _right_column: VBoxContainer
var _confirm_button: Button
var _focused_character: Character = null


func _ready() -> void:
	add_theme_constant_override("separation", 16)

	# 不套羊皮紙面板——只在右邊畫一條線分隔右欄,取代原本獨立一顆固定尺寸羊皮紙面板的
	# 設計,比照 marriage_proposal_panel.gd 的既有慣例。
	var detail_panel := PanelContainer.new()
	detail_panel.add_theme_stylebox_override("panel", UiStyle.right_border_style())
	add_child(detail_panel)

	_detail_view = CharacterDetailView.new()
	_detail_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 只留最外層 CharacterSelectOverlay 一個捲動框(見該檔案開頭註解),分頁內容不再另包
	# 一層獨立 ScrollContainer 搶捲動手感。
	_detail_view.scrollable_tabs = false
	detail_panel.add_child(_detail_view)

	_right_column = VBoxContainer.new()
	_right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_column.add_theme_constant_override("separation", 10)
	add_child(_right_column)

	context_box = VBoxContainer.new()
	context_box.add_theme_constant_override("separation", 6)
	_right_column.add_child(context_box)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 8)
	button_row.alignment = BoxContainer.ALIGNMENT_END

	var cancel_button := Button.new()
	cancel_button.text = "取消"
	UiStyle.apply_wood_plaque_button(cancel_button, 16.0, 6.0)
	cancel_button.add_theme_font_size_override("font_size", 16)
	cancel_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	cancel_button.pressed.connect(func() -> void: cancelled.emit())
	button_row.add_child(cancel_button)

	_confirm_button = Button.new()
	_confirm_button.text = DEFAULT_CONFIRM_LABEL
	UiStyle.apply_wood_plaque_button(_confirm_button, 16.0, 6.0)
	_confirm_button.add_theme_font_size_override("font_size", 16)
	_confirm_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_confirm_button.disabled = true
	_confirm_button.pressed.connect(func() -> void: character_confirmed.emit(_focused_character))
	button_row.add_child(_confirm_button)

	# button_row 先建好放最後面,_select_bar 要插在 context_box 跟 button_row 中間——
	# setup() 才會建立 _select_bar(比照 CharacterSelectBar 自身「先掛進場景樹、再 setup()
	# 灌資料」的慣例),這裡先把 button_row 加進去佔住最後一個位置。
	_right_column.add_child(button_row)


## characters 為空時直接顯示提示文字,不留一個永遠選不出東西的空清單——呼叫端不需要
## 各自判斷是否要呼叫 setup()。initial_focus 選填:一開始就聚焦顯示某人(例如更換整團
## 領導人時原本的領導人)。confirm_label 選填:換成更貼合情境的按鈕文字(例如「設為
## 領導人」)。
func setup(characters: Array[Character], card_factory: Callable, initial_sort_key: int = -1, show_weapon_filter: bool = false, initial_focus: Character = null, confirm_label: String = DEFAULT_CONFIRM_LABEL) -> void:
	_confirm_button.text = confirm_label

	if characters.is_empty():
		var empty_label := Label.new()
		empty_label.text = "沒有可選擇的角色"
		empty_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
		context_box.add_child(empty_label)
		return

	_select_bar = CharacterSelectBar.new()
	_right_column.add_child(_select_bar)
	_right_column.move_child(_select_bar, context_box.get_index() + 1)
	_select_bar.character_selected.connect(_on_card_selected)
	_select_bar.setup(characters, card_factory, initial_sort_key, show_weapon_filter)

	if initial_focus != null and characters.has(initial_focus):
		_focus(initial_focus)
		_select_bar.set_selected(initial_focus)


## 呼叫端在 setup() 之後往 context_box 塞情境說明文字用的小 helper,跟 base_action_panel.gd
## 既有的 _add_label() 同一套樣式,不用各自重複組 Label。
func add_context_line(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	context_box.add_child(label)


func _on_card_selected(character: Character) -> void:
	_focus(character)


func _focus(character: Character) -> void:
	_focused_character = character
	_detail_view.set_character(character)
	_confirm_button.disabled = false
