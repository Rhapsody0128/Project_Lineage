class_name UiStyle
extends RefCounted

## 共用的 StyleBoxFlat 邊框樣式建構器,取代 battle_party_roster.gd/battle_report_list.gd/
## character_panel.gd 四處各自手刻同一種「背景色 + 四邊等寬邊框 + 四角同半徑圓角」樣式碼。
## 回傳的 StyleBoxFlat 仍是一般可變物件,呼叫端要動態改邊框顏色(例如放技能時頭像框
## 高亮)一樣直接改回傳值的 border_color,不影響這裡。

static func bordered_panel(
	bg: Color,
	border_color: Color,
	border_width: int = 2,
	corner_radius: int = 0,
	content_margin_h: float = 0.0,
	content_margin_v: float = 0.0
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner_radius)
	style.content_margin_left = content_margin_h
	style.content_margin_right = content_margin_h
	style.content_margin_top = content_margin_v
	style.content_margin_bottom = content_margin_v
	return style
