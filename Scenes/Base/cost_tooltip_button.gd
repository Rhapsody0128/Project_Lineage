class_name CostTooltipButton
extends Button

## 「建造」「升級」鈕專用:預設 tooltip_text 只能顯示純文字,沒辦法內嵌資源圖示。這裡
## override _make_custom_tooltip() 組一個「圖示 + 文字」的 Control 取代預設純文字 tooltip
## (見 Scenes/Base/base_action_panel.gd 的 _build_build_button()/_build_upgrade_button())。
## tooltip_text 仍然照舊設定(見呼叫端),當純文字備援——理論上 Godot 只要
## _make_custom_tooltip() 回傳非 null 就會改顯示這裡組的 Control,tooltip_text 不會被用到,
## 但保留備援不會有副作用,萬一自訂 tooltip 沒生效也不會整顆按鈕變成完全沒有提示。
##
## 回傳的 Control 不會直接就是畫面上看到的整顆 tooltip——Godot 會另外包一層引擎內建的
## PopupPanel(theme 型別 "TooltipPanel",套用全域預設主題的灰底樣式),把這裡回傳的
## Control 塞進去當子節點,四邊留一點固定內距。之前這裡自己疊了一層 PanelContainer +
## 深色圓角邊框,結果變成「兩層底」:外層引擎內建的方形灰底 + 內層自己畫的圓角深色底,
## 兩者形狀對不齊,四個角落跟邊緣就會露出外層的灰色——看起來像多一圈沒對齊的遮罩。
## 這裡改成只回傳 MarginContainer(純負責留白,不畫底色/邊框),讓外層引擎內建的
## TooltipPanel 底色統一當唯一一層背景,跟遊戲裡其他所有 tooltip_text 純文字提示框
## 用同一套底色,不會再對不齊。
const _ICON_SIZE := Vector2(26, 26)
const _TEXT_COLOR := Color(0.95, 0.9, 0.8, 1)
const _WARNING_COLOR := Color(0.95, 0.55, 0.4, 1)
const _CONTENT_MARGIN_H := 12
const _CONTENT_MARGIN_V := 8

## resource_type -> 需要的數量,天數,額外提示行(「市鎮中心等級不足」「資材不足」等)。
var _cost: Dictionary = {}
var _days: int = 0
var _extra_lines: Array[String] = []


func set_cost_tooltip(cost: Dictionary, days: int, extra_lines: Array[String] = []) -> void:
	_cost = cost
	_days = days
	_extra_lines = extra_lines


func _make_custom_tooltip(_for_text: String) -> Object:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", _CONTENT_MARGIN_H)
	margin.add_theme_constant_override("margin_right", _CONTENT_MARGIN_H)
	margin.add_theme_constant_override("margin_top", _CONTENT_MARGIN_V)
	margin.add_theme_constant_override("margin_bottom", _CONTENT_MARGIN_V)

	## 不強制固定寬度——讓面板依內容自然縮放(耗材種類少就窄矮、種類多就自動變寬)。
	## 底下每個 Label 故意不開 autowrap:Label 開了 autowrap 之後回報的 minimum_size.x
	## 只算「最長不可斷字單元」(通常就是幾個字寬),不是整行文字寬度,容器沒有其他東西
	## 撐寬度的話會整個縮到很窄、文字被迫逐字換行(這裡的耗材/天數本來就是短句,不需要
	## 換行,不開 autowrap 才能讓容器照單行文字的真實寬度自然撐開)。
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 3)
	margin.add_child(content)

	for resource_type in _cost:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		content.add_child(row)

		var icon := TextureRect.new()
		icon.custom_minimum_size = _ICON_SIZE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = load(GameEnums.resource_type_icon_path(resource_type)) as Texture2D
		row.add_child(icon)

		var owned := BaseResourceStore.get_amount(resource_type)
		var required: int = _cost[resource_type]
		var label := Label.new()
		label.text = "%s 現有%d / 需要%d" % [GameEnums.resource_string_label(resource_type), owned, required]
		label.add_theme_color_override("font_color", _TEXT_COLOR)
		row.add_child(label)

	var days_label := Label.new()
	days_label.text = "天數：%d 天" % _days
	days_label.add_theme_color_override("font_color", _TEXT_COLOR)
	content.add_child(days_label)

	for line in _extra_lines:
		var extra_label := Label.new()
		extra_label.text = line
		extra_label.add_theme_color_override("font_color", _WARNING_COLOR)
		content.add_child(extra_label)

	return margin
