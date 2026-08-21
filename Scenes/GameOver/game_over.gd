extends Control

# =========================================================
# 隊伍全滅畫面:CharacterDeathController.kill() 發現 PartyStore.party.characteres 死到
# 淨空時直接 NavigationStore.go_to() 切過來(見該檔案),不是玩家手動觸發的場景,所以
# 沒有「返回」按鈕,只有「讀取存檔」(共用 SaveSlotPicker.open_load_menu(),讀檔成功會
# 自動切去大地圖)跟「回到主選單」兩個出口。
# =========================================================

@onready var _load_game_button: Button = $CenterContainer/VBoxContainer/LoadGame
@onready var _back_to_menu_button: Button = $CenterContainer/VBoxContainer/BackToMenu


func _ready() -> void:
	UiStyle.apply_wood_plaque_button(_load_game_button)
	UiStyle.apply_wood_plaque_button(_back_to_menu_button)


func _on_load_game_pressed() -> void:
	SaveSlotPicker.open_load_menu()


func _on_back_to_menu_pressed() -> void:
	NavigationStore.go_to("res://Scenes/main.tscn")
