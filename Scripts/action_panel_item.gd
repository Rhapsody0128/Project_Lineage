class_name ActionPanelItem
extends RefCounted

## ActionPanel(Scenes/ActionPanel/action_panel.gd)清單裡的一列資料:icon_path 是頭像/
## 圖示資源路徑(留空不顯示),title/subtitle 是文字說明,button_label 是這一列的操作
## 按鈕文字,on_selected 是按下按鈕要執行的動作——ActionPanel 本身不知道也不需要知道
## on_selected 實際做了什麼(比照 DialogueChoice.on_selected 的分工),呼叫端(例如
## System/event/town/town_tavern_event.gd 的招募清單)自己決定要不要在 callback 裡順便
## 呼叫 ActionPanel.close()。disable_after_select 選填:按下後這一列的按鈕要不要直接
## 變 disabled(例如招募過的英雄不能重複招募,但面板本身留著讓玩家繼續招募清單裡其他
## 幾位)——預設 false,維持「按下去不影響按鈕本身狀態」的一般行為。
var icon_path: String
var title: String
var subtitle: String
var button_label: String
var on_selected: Callable
var disable_after_select: bool


func _init(p_title: String, p_button_label: String, p_on_selected: Callable, p_icon_path: String = "", p_subtitle: String = "", p_disable_after_select: bool = false) -> void:
	title = p_title
	button_label = p_button_label
	on_selected = p_on_selected
	icon_path = p_icon_path
	subtitle = p_subtitle
	disable_after_select = p_disable_after_select
