extends Control

# =========================================================
# 祖譜畫面殼:背景/標題/返回鍵在 .tscn 固定排版,樹狀圖本身(FamilyTreeCanvas)
# 節點數量隨家族大小變動,程式化建構、放進 ScrollContainer 捲動。
#
# 入口:CharacterDetailView 家族分頁「觀看祖譜」按鈕呼叫
# SceneHandoffStore.queue("family_tree_focus", character) 再切場景過來,這裡用
# take() 一次性讀出——不是 Dialogue 那種需要撐住 lambda 生命週期的用途,讀完即可清空。
# =========================================================

@onready var canvas: FamilyTreeCanvas = $ScrollContainer/Canvas


func _ready() -> void:
	var handoff := SceneHandoffStore.take("family_tree_focus")
	var focus_character: Character = handoff.payload as Character if handoff != null else null
	if focus_character != null:
		canvas.render(focus_character)


func _on_back_pressed() -> void:
	NavigationStore.go_back()
