class_name ActionPanelItem
extends RefCounted

## ActionPanel(Scenes/ActionPanel/action_panel.gd)清單裡的一列資料:icon_path 是頭像/
## 圖示資源路徑(留空不顯示),title/subtitle 是文字說明,button_label 是這一列的操作
## 按鈕文字,on_selected 是按下按鈕要執行的動作——ActionPanel 本身不知道也不需要知道
## on_selected 實際做了什麼(比照 DialogueChoice.on_selected 的分工),呼叫端(例如
## System/event/town/town_tavern_event.gd 的招募清單)自己決定要不要在 callback 裡順便
## 呼叫 ActionPanel.close()。disable_after_select 選填:按下後這一列的按鈕要不要直接
## 變 disabled(例如招募過的英雄不能重複招募,但面板本身留著讓玩家繼續招募清單裡其他
## 幾位)——預設 false,維持「按下去不影響按鈕本身狀態」的一般行為。disable_after_select
## 為 true 時,on_selected 的回傳值(bool)決定要不要真的 disable——沒有回傳值(void)
## 視同成功,維持舊行為;明確回傳 false 代表這次動作沒有成功(例如
## CharacterRosterStore.try_add() 角色列已滿而失敗),按鈕維持可按,讓玩家補救
## (騰出空位)後可以直接再按一次,不用整個面板關掉重開才能重試。initial_disabled 選填:
## 這一列一開始就要是 disabled(例如 TownTavernEvent 重新開面板時,清單裡上次已經招募過
## 的英雄不該又能按一次)——跟 disable_after_select 是兩件事,前者是「開面板當下就已經
## 是這個狀態」,後者是「這次操作完才變成這個狀態」。
var icon_path: String
var title: String
var subtitle: String
var button_label: String
var on_selected: Callable
var disable_after_select: bool
var initial_disabled: bool


func _init(p_title: String, p_button_label: String, p_on_selected: Callable, p_icon_path: String = "", p_subtitle: String = "", p_disable_after_select: bool = false, p_initial_disabled: bool = false) -> void:
	title = p_title
	button_label = p_button_label
	on_selected = p_on_selected
	icon_path = p_icon_path
	subtitle = p_subtitle
	disable_after_select = p_disable_after_select
	initial_disabled = p_initial_disabled
