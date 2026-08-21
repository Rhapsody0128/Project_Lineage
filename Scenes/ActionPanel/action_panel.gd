extends CanvasLayer

# =========================================================
# 通用彈出式操作面板(以 autoload 掛載於 project.godot,任何場景/Dialogue 都可呼叫
# ActionPanel.open(...) 疊加顯示;外殼比照 CharacterPanel/AskBattle 的彈出式對話框
# 寫法——背景遮罩 + 面板 + 關閉鍵)。跟 CharacterPanel/AskBattle 不同的是這裡的清單
# 內容/大小/按鈕動作完全由呼叫端決定(見 Scripts/action_panel_item.gd 的 ActionPanelItem),
# 不綁定任何特定用途——例如 System/event/town/town_tavern_event.gd 的酒館老闆用這裡
# 列出可招募的隨機英雄,之後其他 Dialogue 情境要彈類似的清單/操作浮框,一律呼叫這裡,
# 不要另開新的彈出面板。面板底圖固定用 Images/UI/panel_1980x1080.png(木框+羊皮紙,見
# action_panel.tscn 的 StyleBoxTexture,texture_margin/content_margin 依這張圖的實際邊框
# 厚度量出來,九宮格切片避免邊框被拉伸變形),清單/標題文字顏色跟著改成暖色系配色
# (_TEXT_COLOR/_SUBTITLE_COLOR),不是任意場景都能沿用深色底金字那一套。
# =========================================================

## 視窗固定 1600x900(見 project.godot),預設面板大約佔 3/4 畫面。
const DEFAULT_MIN_SIZE := Vector2(1200, 675)
const ICON_SIZE := Vector2(64, 64)

## 面板背景換成 panel_1980x1080.png(木框+羊皮紙)之後,列跟文字改用暖色系
## (UiStyle.PARCHMENT_* 系列),配合淺色羊皮紙底色維持可讀性——原本的深藍底金字是給
## 深色面板配色用的。
const _TEXT_COLOR := UiStyle.PARCHMENT_TEXT_COLOR
const _SUBTITLE_COLOR := UiStyle.PARCHMENT_SUBTITLE_COLOR

@onready var root: Control = $Root
@onready var panel_box: PanelContainer = $Root/CenterContainer/PanelBox
@onready var title_label: Label = $Root/CenterContainer/PanelBox/Margin/Content/TopBar/TitleLabel
@onready var close_button: Button = $Root/CenterContainer/PanelBox/Margin/Content/TopBar/CloseButton
@onready var scroll_container: ScrollContainer = $Root/CenterContainer/PanelBox/Margin/Content/ScrollContainer
@onready var items_list: VBoxContainer = $Root/CenterContainer/PanelBox/Margin/Content/ScrollContainer/ItemsList
@onready var empty_label: Label = $Root/CenterContainer/PanelBox/Margin/Content/EmptyLabel

## 面板關閉時(不管是按 × 還是清單項目自己的 on_selected 呼叫 close())執行一次,
## 呼叫端用來接續「關掉面板之後要去哪」(例如 TownTavernEvent 招募完/不招募都要切回
## 地點選單)——比照 AskBattle.ask() 的 on_result 選填加碼寫法。
var _on_close: Callable = Callable()

## 標題列上除了 CloseButton 以外的額外按鈕(見 set_title_action_button()),目前只有
## Scenes/Base/base_action_panel.gd 的建造/升級鈕會用到——open()/open_custom() 一律先
## 清空,不會讓上一個呼叫端塞的按鈕殘留到下一次開的完全不同的清單/內容(例如酒館招募)。
var _title_action_button: Button = null


func _ready() -> void:
	root.visible = false
	UiStyle.apply_parchment_panel(panel_box, 1200.0, 675.0)
	UiStyle.apply_wood_plaque_button(close_button, 10.0, 4.0)
	close_button.add_theme_font_size_override("font_size", 18)
	close_button.pressed.connect(close)
	UiStyle.apply_parchment_scrollbar(scroll_container)


## 任何場景/Dialogue 都可呼叫:ActionPanel.open(title, items)。on_close 選填,面板關閉
## 時執行一次;min_size 選填,不同情境面板大小不一定,留空用預設值
## (DEFAULT_MIN_SIZE)。
func open(title: String, items: Array[ActionPanelItem], on_close: Callable = Callable(), min_size: Vector2 = DEFAULT_MIN_SIZE) -> void:
	_on_close = on_close
	title_label.text = title
	set_title_action_button(null)
	panel_box.custom_minimum_size = min_size
	_rebuild_items(items)
	root.visible = true


## 跟 open() 共用同一個外框(背景遮罩/PanelBox/Margin/TopBar/關閉鍵位置全部一樣),差別
## 是內容區塊不是靠 ActionPanelItem 清單自動排版列出來,而是呼叫端自己組好一整個 Control
## 直接塞進來——例如 System/event/base/base_building_event.gd 的根據地建築面板,內容
## (等級/升級/派遣角色等)因事件而異,但外殼(離開鈕位置、Margin、面板大小)要保持
## 跟這裡列清單的用途一致,不要另外開一個長相不同的面板。content 的生命週期跟著這次
## 顯示走,下次 open()/open_custom() 呼叫或整包場景關閉都會被清掉,呼叫端不用自己管理。
func open_custom(title: String, content: Control, on_close: Callable = Callable(), min_size: Vector2 = DEFAULT_MIN_SIZE) -> void:
	_on_close = on_close
	title_label.text = title
	set_title_action_button(null)
	panel_box.custom_minimum_size = min_size
	for child in items_list.get_children():
		child.queue_free()
	empty_label.visible = false
	items_list.add_child(content)
	root.visible = true


## 標題列(TitleLabel 右邊、CloseButton 左邊)塞一顆額外按鈕,例如
## Scenes/Base/base_action_panel.gd 的「建造」「升級」鈕——名稱/等級跟操作鈕同一行,
## 不用在內容區塊多開一行重複顯示名稱。傳 null 清掉目前這顆(不論是不是同一顆),
## open()/open_custom() 開新面板時也會呼叫一次,確保不會把上一個呼叫端塞的按鈕殘留到
## 下一次開的完全不同的清單/內容。按鈕本身的樣式/disabled/tooltip/訊號一律由呼叫端
## 決定,這裡只負責擺放位置。
func set_title_action_button(button: Button) -> void:
	if _title_action_button != null:
		_title_action_button.get_parent().remove_child(_title_action_button)
		_title_action_button.queue_free()
		_title_action_button = null
	if button == null:
		return
	_title_action_button = button
	var top_bar := close_button.get_parent()
	top_bar.add_child(button)
	top_bar.move_child(button, close_button.get_index())


## trigger_callback 預設 true(維持原本行為:呼叫 open()/open_custom() 時傳入的
## on_close 接續動作,例如 TownTavernEvent 招募面板關閉後回地點選單)。呼叫端如果
## 已經自己決定好接下來要切去哪個場景(例如 TownTavernEvent 角色列表已滿,選「是」
## 改去 CharacterRoster 解雇角色,見該檔案),要傳 false 蓋掉原本的預設接續,
## 避免兩邊搶著切場景。
func close(trigger_callback: bool = true) -> void:
	root.visible = false
	var callback := _on_close
	_on_close = Callable()
	if trigger_callback and callback.is_valid():
		callback.call()


func _rebuild_items(items: Array[ActionPanelItem]) -> void:
	for child in items_list.get_children():
		child.queue_free()

	empty_label.visible = items.is_empty()

	for item in items:
		items_list.add_child(_build_row(item))


func _build_row(item: ActionPanelItem) -> Control:
	var row_panel := PanelContainer.new()
	row_panel.add_theme_stylebox_override("panel", UiStyle.parchment_row_style(
		UiStyle.PARCHMENT_ROW_BORDER, 1, 12, 12.0, 8.0, 6
	))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row_panel.add_child(row)

	var icon := TextureRect.new()
	icon.custom_minimum_size = ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	if not item.icon_path.is_empty():
		icon.texture = load(item.icon_path) as Texture2D
	row.add_child(icon)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var item_title_label := Label.new()
	item_title_label.text = item.title
	item_title_label.add_theme_color_override("font_color", _TEXT_COLOR)
	item_title_label.add_theme_font_size_override("font_size", 18)
	text_box.add_child(item_title_label)

	if not item.subtitle.is_empty():
		var subtitle_label := Label.new()
		subtitle_label.text = item.subtitle
		subtitle_label.add_theme_color_override("font_color", _SUBTITLE_COLOR)
		subtitle_label.add_theme_font_size_override("font_size", 14)
		text_box.add_child(subtitle_label)

	row.add_child(text_box)

	var action_button := Button.new()
	action_button.text = item.button_label
	UiStyle.apply_wood_plaque_button(action_button, 16.0, 6.0)
	action_button.add_theme_font_size_override("font_size", 16)
	action_button.disabled = item.initial_disabled
	action_button.pressed.connect(func() -> void:
		var succeeded: Variant = true
		if item.on_selected.is_valid():
			succeeded = item.on_selected.call()
		# on_selected 沒有回傳值(void)時 succeeded 會是 null——視同成功,維持舊行為;
		# 只有明確回傳 false 才擋下 disable(見 ActionPanelItem.disable_after_select 註解)。
		if item.disable_after_select and succeeded != false:
			action_button.disabled = true
	)
	row.add_child(action_button)

	return row_panel
