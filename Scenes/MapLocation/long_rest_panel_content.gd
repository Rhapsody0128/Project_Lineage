class_name LongRestPanelContent
extends VBoxContainer

## 「長休」彈出面板的內容(外殼共用 Scenes/ActionPanel/action_panel.gd 的
## open_custom(),比照 Scenes/MapLocation/market_panel_content.gd 的寫法)——不切場景,
## 只負責讓玩家用滑桿選 1~365 天,按下確定後把天數交給呼叫端(map_location.gd 的
## _on_long_rest_confirmed()),實際退回大地圖/調倍速/切場景都由呼叫端處理,這裡不碰
## WorldTimeStore/MapSessionStore。

const MIN_DAYS := 1
const MAX_DAYS := 365
const DEFAULT_DAYS := 30

var _slider: HSlider
var _days_label: Label
var _on_confirm: Callable = Callable()


## 呼叫端(map_location.gd)在 ActionPanel.open_custom() 之後呼叫,傳入
## func(days: int) -> void 接手後續流程。
func setup(on_confirm: Callable) -> void:
	_on_confirm = on_confirm


func _ready() -> void:
	add_theme_constant_override("separation", 10)

	var description := Label.new()
	description.text = "選擇長休天數,確定後會退回大地圖並讓時間以 %d 倍速快速流逝,直到天數到達,或你提早移動/進行其他操作為止(那時速度會回到 1 倍速)。" % int(WorldTimeStore.SPEED_MULTIPLIERS[4])
	description.autowrap_mode = TextServer.AUTOWRAP_WORD
	description.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	add_child(description)

	var slider_row := HBoxContainer.new()
	slider_row.add_theme_constant_override("separation", 8)
	add_child(slider_row)

	_slider = HSlider.new()
	_slider.min_value = MIN_DAYS
	_slider.max_value = MAX_DAYS
	_slider.step = 1
	_slider.value = DEFAULT_DAYS
	_slider.custom_minimum_size = Vector2(360, 0)
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider.value_changed.connect(_on_slider_value_changed)
	slider_row.add_child(_slider)

	_days_label = Label.new()
	_days_label.custom_minimum_size = Vector2(70, 0)
	_days_label.text = "%d 天" % int(_slider.value)
	_days_label.add_theme_color_override("font_color", UiStyle.PARCHMENT_TEXT_COLOR)
	slider_row.add_child(_days_label)

	var confirm_button := Button.new()
	confirm_button.text = "確定"
	UiStyle.apply_wood_plaque_button(confirm_button, 16.0, 6.0)
	confirm_button.add_theme_font_size_override("font_size", 16)
	confirm_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	confirm_button.pressed.connect(func() -> void:
		if _on_confirm.is_valid():
			_on_confirm.call(int(_slider.value))
	)
	add_child(confirm_button)


func _on_slider_value_changed(value: float) -> void:
	_days_label.text = "%d 天" % int(value)
