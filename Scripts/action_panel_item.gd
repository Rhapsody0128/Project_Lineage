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
## 是這個狀態」,後者是「這次操作完才變成這個狀態」。icon_blacked_out 選填:圖示照樣載入
## icon_path 的貼圖,但整張塗成純黑剪影(見 TownTavernEvent 的特殊推薦——招募前不讓玩家
## 看到長相,只露出名字/等級,但仍要有一塊「頭像形狀」的視覺存在,不是留空)。
## disabled_label 選填:disable_after_select 這次操作成功、按鈕真的變 disabled 的當下,
## 順便把按鈕文字換成這個字串(例如 RECRUIT_BUTTON_LABEL → RECRUITED_BUTTON_LABEL)——
## 沒有這欄以前按下去按鈕只會變灰,文字停在原本那句,要關掉面板重開才會顯示成
## 「已招募」,誤導玩家以為還能再按一次。留空(預設)維持舊行為,文字不變。GDScript
## 的 `.new()` 建構子呼叫上限是 8 個參數(超過會噴 "Too many arguments"),`_init()` 的
## 位置參數已經用滿,所以這欄不放進 `_init()`,呼叫端建構完物件後直接賦值
## (`item.disabled_label = ...`,見 TownTavernEvent 的三個 `_build_*_item()`)。
var icon_path: String
var title: String
var subtitle: String
var button_label: String
var on_selected: Callable
var disable_after_select: bool
var initial_disabled: bool
var icon_blacked_out: bool
var disabled_label: String


func _init(p_title: String, p_button_label: String, p_on_selected: Callable, p_icon_path: String = "", p_subtitle: String = "", p_disable_after_select: bool = false, p_initial_disabled: bool = false, p_icon_blacked_out: bool = false) -> void:
	title = p_title
	button_label = p_button_label
	on_selected = p_on_selected
	icon_path = p_icon_path
	subtitle = p_subtitle
	disable_after_select = p_disable_after_select
	initial_disabled = p_initial_disabled
	icon_blacked_out = p_icon_blacked_out
