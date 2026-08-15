extends Node

# =========================================================
# Scenes/Dialogue/dialogue_box.tscn 的交接點(autoload,見 project.godot)。跟
# BattleReportStore/MapSessionStore 同一套「mailbox」模式:呼叫端把要播的 Dialogue
# 跟播完之後要切去的場景路徑存進來,再 change_scene_to_file 去 dialogue_box.tscn,
# dialogue_box.gd 的 _ready() 讀出來播放,播完自動切去 next_scene_path。
# =========================================================

var pending_dialogue: Dialogue = null
var next_scene_path: String = ""


func queue(dialogue: Dialogue, p_next_scene_path: String) -> void:
	pending_dialogue = dialogue
	next_scene_path = p_next_scene_path
