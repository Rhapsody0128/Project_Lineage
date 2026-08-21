class_name SaveSlotPicker
extends RefCounted

# =========================================================
# 存檔/讀檔的選位選單,共用元件——HeaderBar 的「存檔」跟 Scenes/Base/base.gd 的「讀取」
# 都呼叫這裡,不用各自組一份幾乎一樣的清單畫面。外殼直接借 ActionPanel(autoload)的
# open(),跟酒館招募清單同一套彈窗長相,不另開新的彈出面板。
# =========================================================

const SLOT_LABELS := {1: "存檔位一", 2: "存檔位二", 3: "存檔位三"}


## HeaderBar「存檔」選單:每個存檔位顯示目前內容摘要(空/世界時間+存檔時間),按下去
## 直接存檔;已有存檔的位子先跳 ConfirmDialog 問是否覆蓋,避免手滑蓋掉舊進度。
static func open_save_menu() -> void:
	var items: Array[ActionPanelItem] = []
	for slot in range(1, SaveLoadStore.SLOT_COUNT + 1):
		items.append(_build_save_item(slot))
	ActionPanel.open("存檔", items)


static func _build_save_item(slot: int) -> ActionPanelItem:
	var summary := SaveLoadStore.get_slot_summary(slot)
	var on_selected := func() -> void:
		if summary.is_empty():
			_do_save(slot)
		else:
			ConfirmDialog.ask(
				"%s 已有存檔，確定要覆蓋嗎？" % SLOT_LABELS[slot],
				func() -> void: _do_save(slot)
			)
	return ActionPanelItem.new(SLOT_LABELS[slot], "存檔", on_selected, "", _format_subtitle(summary))


static func _do_save(slot: int) -> void:
	ActionPanel.close(false)
	if SaveLoadStore.save_game(slot):
		MessageBar.show_message("已儲存至%s" % SLOT_LABELS[slot])
	else:
		MessageBar.show_message("存檔失敗")


## Scenes/Base/base.gd「讀取」選單:只有已存檔的位子能點,選定後先跳 ConfirmDialog
## 提醒未存檔進度會遺失,確認後讀檔並直接切去大地圖(見 SaveLoadStore.load_game()
## 還原的是全域 store 狀態,不含玩家在地圖上的座標,讀檔後一律從大地圖重新開始)。
static func open_load_menu() -> void:
	var items: Array[ActionPanelItem] = []
	for slot in range(1, SaveLoadStore.SLOT_COUNT + 1):
		items.append(_build_load_item(slot))
	ActionPanel.open("讀取存檔", items)


static func _build_load_item(slot: int) -> ActionPanelItem:
	var summary := SaveLoadStore.get_slot_summary(slot)
	if summary.is_empty():
		return ActionPanelItem.new(SLOT_LABELS[slot], "（無存檔）", Callable(), "", "尚未存檔")

	var on_selected := func() -> void:
		ConfirmDialog.ask(
			"確定要讀取「%s」嗎？目前未存檔的進度將會遺失。" % SLOT_LABELS[slot],
			func() -> void: _do_load(slot)
		)
	return ActionPanelItem.new(SLOT_LABELS[slot], "讀取", on_selected, "", _format_subtitle(summary))


static func _do_load(slot: int) -> void:
	ActionPanel.close(false)
	if SaveLoadStore.load_game(slot):
		NavigationStore.go_to("res://Scenes/Map/map.tscn")
	else:
		MessageBar.show_message("讀取失敗")


static func _format_subtitle(summary: Dictionary) -> String:
	if summary.is_empty():
		return "（尚無存檔）"
	return "%s｜存於 %s" % [summary.get("world_time_display", ""), summary.get("saved_at", "")]
