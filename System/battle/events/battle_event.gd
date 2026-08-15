class_name BattleEvent
extends RefCounted

## 型別化戰報事件基底類別,取代舊版 Array[Dictionary] 的 battle_log,見 Spec.md 一。
## 每種事件各自一個子類別(同資料夾底下),欄位固定、建構時就決定型別,
## 取代原本 event.type 字串比對 + Dictionary 動態欄位的設計。事件本身仍是「當下快照」——
## 建構時就把數值/名稱都存進來,重播時不會、也不該回頭讀取物件目前狀態
## (物件狀態在模擬跑完後已經是最終值)。

var event_type: GameEnums.BattleEventType
## 判定/骰值/公式全文,供戰報 UI 用 RichTextLabel 的 [hint=...] 包住彈出說明;
## 不能含方括號 [ ],會被誤判成 BBCode 標籤提早截斷。
var detail: String

func _init(p_event_type: GameEnums.BattleEventType, p_detail: String = "") -> void:
	event_type = p_event_type
	detail = p_detail
