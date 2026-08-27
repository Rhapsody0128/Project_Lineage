class_name MoraleStatusButton
extends Button

## HeaderBar 左側士氣顯示鈕:平時只顯示「士氣 XX%」,詳細成因(維持費/供應狀態/近期
## 戰況/其他事件/目前效果)靠 hover 顯示的自訂 tooltip 呈現——跟 CostTooltipButton
## (Scenes/Base/cost_tooltip_button.gd)同一套 _make_custom_tooltip() 慣例:外層引擎
## 內建的 TooltipPanel 已經有底色,這裡只回傳 MarginContainer 負責留白排版,不再疊一層
## 自己的底色/邊框(疊了會兩層底對不齊,見 CostTooltipButton 檔頭註解)。
##
## 呼叫端(header_bar.gd)自己接 MoraleStore.changed 更新 text,這裡只負責 tooltip 內容
## 的建構,每次 hover 都即時讀 MoraleStore 目前值組字串,不會有資料過期的問題。

const _TEXT_COLOR := Color(0.9, 0.9, 0.85, 1)
const _POSITIVE_COLOR_HEX := "5FE05F"
const _NEGATIVE_COLOR_HEX := "F05C5C"
const _SECTION_GAP := 6
const _CONTENT_MARGIN_H := 12
const _CONTENT_MARGIN_V := 8


func _make_custom_tooltip(_for_text: String) -> Object:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", _CONTENT_MARGIN_H)
	margin.add_theme_constant_override("margin_right", _CONTENT_MARGIN_H)
	margin.add_theme_constant_override("margin_top", _CONTENT_MARGIN_V)
	margin.add_theme_constant_override("margin_bottom", _CONTENT_MARGIN_V)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", _SECTION_GAP)
	margin.add_child(content)

	var value := MoraleStore.value
	_add_label(content, "軍隊士氣：%d%%（%s）" % [roundi(value), MoraleRule.tier_label(value)])

	content.add_child(HSeparator.new())
	_add_label(content, "本月維持費")
	_add_delta_label(content, "糧食", -float(MoraleStore.last_food_cost))
	_add_delta_label(content, "薪水", -float(MoraleStore.last_wage_cost))
	_add_label(content, "隊伍人數：%d" % MoraleStore.get_roster_size())

	content.add_child(HSeparator.new())
	_add_label(content, "本月狀態")
	_add_label(content, "糧食供應：%s" % ("不足" if MoraleStore.last_food_short else "充足"))
	_add_label(content, "薪水支付：%s" % ("不足" if MoraleStore.last_wage_short else "充足"))
	## 「不足」只是文字,玩家看不出扣了多少士氣——這裡把 MoraleStore.settle() 實際套用的
	## SHORTAGE_SINGLE_PENALTY/SHORTAGE_BOTH_PENALTY 數值攤開顯示,對齊「四、維持費不足」
	## 的公式,不是只有文字狀態沒有數字。
	if not is_equal_approx(MoraleStore.last_shortage_penalty, 0.0):
		_add_delta_label(content, _shortage_penalty_label(), MoraleStore.last_shortage_penalty)

	## get_recent_battle_log()/get_recent_event_log() 讀取當下就會先淘汰過期紀錄(見
	## MoraleStore.LOG_EXPIRY_DAYS),不是只在寫入當下才清——就算長時間沒有新戰鬥/事件、
	## 也沒人打開過這個 tooltip,這裡讀到的仍然是「此刻算起還在期限內」的清單。
	var recent_battle_log := MoraleStore.get_recent_battle_log()
	if not recent_battle_log.is_empty():
		content.add_child(HSeparator.new())
		_add_label(content, "近期戰況")
		var battle_totals := _group_by_label(recent_battle_log)
		for label in battle_totals:
			_add_delta_label(content, label, battle_totals[label])

	var recent_event_log := MoraleStore.get_recent_event_log()
	if not recent_event_log.is_empty():
		content.add_child(HSeparator.new())
		_add_label(content, "其他事件")
		var event_totals := _group_by_label(recent_event_log)
		for label in event_totals:
			_add_delta_label(content, label, event_totals[label])

	content.add_child(HSeparator.new())
	_add_label(content, "目前效果")
	for line in MoraleRule.effect_description_lines(value):
		_add_label(content, line)

	return margin


## 缺糧/欠薪同時發生時是單一「更嚴重」的懲罰(見 MoraleStore.SHORTAGE_BOTH_PENALTY 註解),
## 不是兩筆分開扣加總,label 要一起講清楚是哪些項目造成的,不能只寫「維持費短缺」。
func _shortage_penalty_label() -> String:
	if MoraleStore.last_food_short and MoraleStore.last_wage_short:
		return "糧食+薪水短缺"
	if MoraleStore.last_food_short:
		return "糧食短缺"
	return "薪水短缺"


## 依 label 分組加總:同一種事件類型(連續好幾場「勝利」,或跨好幾個月各自的「角色誕下
## 新生兒」)不逐筆各占一行,只顯示一行「這個類型目前的加總」——不寫 x 幾次這種倍數註記,
## 數字本身就是總和,見呼叫端 _add_delta_label()。Dictionary 在 GDScript 保留插入順序,
## 顯示順序等於「這個類型第一次出現」的順序,不會每次刷新就洗牌。
func _group_by_label(entries: Array[Dictionary]) -> Dictionary:
	var totals: Dictionary = {}
	for entry in entries:
		totals[entry.label] = totals.get(entry.label, 0.0) + entry.delta
	return totals


func _add_label(content: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", _TEXT_COLOR)
	content.add_child(label)


## delta 為 0 時用中性顏色顯示「0」,不套用正/負色——維持費/戰績/事件目前都不會出現
## 剛好 0 的情況,但保留這個分支避免之後新增的事件種類(例如尚未觸發的小型隨機事件)
## 剛好 0 分時被誤染成紅色。
func _add_delta_label(content: VBoxContainer, label_text: String, delta: float) -> void:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.scroll_active = false
	label.add_theme_font_size_override("normal_font_size", 15)

	if is_equal_approx(delta, 0.0):
		label.text = "%s：0" % label_text
	else:
		var color_hex := _POSITIVE_COLOR_HEX if delta > 0.0 else _NEGATIVE_COLOR_HEX
		var sign_text := "+%s" % _format_delta(delta) if delta > 0.0 else _format_delta(delta)
		label.text = "%s：[color=#%s]%s[/color]" % [label_text, color_hex, sign_text]
	content.add_child(label)


func _format_delta(delta: float) -> String:
	var rounded := roundi(delta)
	return str(rounded) if is_equal_approx(delta, float(rounded)) else "%.1f" % delta
