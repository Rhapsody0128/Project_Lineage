class_name FamilyTree
extends Control

# =========================================================
# 祖譜畫面殼:背景/標題/返回鍵在 .tscn 固定排版,樹狀圖本身(FamilyTreeCanvas)
# 節點數量隨家族大小變動,程式化建構、放進 ScrollContainer 捲動。
#
# 入口:CharacterDetailView 家族分頁「觀看祖譜」按鈕、CharacterRoster 左側面板
# 的「觀看祖譜」按鈕(見該檔案 _on_view_family_tree_pressed())都呼叫
# SceneHandoffStore.queue(FamilyTree.FOCUS_MAILBOX_KEY, character) 再切場景過來,
# 這裡用 take() 一次性讀出——不是 Dialogue 那種需要撐住 lambda 生命週期的用途,
# 讀完即可清空。
# =========================================================

## SceneHandoffStore 的 key,呼叫端跟這裡共用同一個常數存取,不要各自硬編字串。
const FOCUS_MAILBOX_KEY := "family_tree_focus"

@onready var canvas: FamilyTreeCanvas = $ScrollContainer/Canvas
@onready var back_button: Button = $TopBar/BackButton


func _ready() -> void:
	UiStyle.apply_wood_plaque_button(back_button, 16.0, 8.0)
	back_button.add_theme_font_size_override("font_size", 18)

	var handoff := SceneHandoffStore.take(FOCUS_MAILBOX_KEY)
	var focus_character: Character = handoff.payload as Character if handoff != null else null
	if focus_character != null:
		canvas.render(focus_character)


func _on_back_pressed() -> void:
	NavigationStore.go_back()
