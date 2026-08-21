extends Control

## 遊戲真正的開場畫面——project.godot 的 run/main_scene 指到這裡,不是直接指到
## main.tscn。目的是把 AssetBundleLoader(Scripts/Autoload/asset_bundle_loader.gd)
## 在 Web 平台下載 Dialogue 圖片包的過程,併入玩家看到的第一個載入畫面,而不是讓
## 玩家先進主選單、點進遊戲後才發現對話背景圖是空的。原生平台/編輯器內
## AssetBundleLoader 一開始就是 is_finished = true,這裡幾乎是無感跳過直接進主選單。

const MAIN_SCENE_PATH := "res://Scenes/main.tscn"

@onready var _progress_bar : ProgressBar = $CenterContainer/VBoxContainer/ProgressBar


func _ready() -> void:
	if AssetBundleLoader.is_finished:
		# _ready() 當下場景樹還在忙著把 Boot 自己加進樹裡,這時直接呼叫
		# change_scene_to_file 會噴「Parent node is busy adding/removing children」,
		# 要 defer 到這輪處理完再切。
		_goto_main.call_deferred()
		return
	AssetBundleLoader.loading_finished.connect(_goto_main)


func _process(_delta: float) -> void:
	if AssetBundleLoader.is_finished:
		return
	_progress_bar.value = AssetBundleLoader.get_progress() * 100.0


func _goto_main() -> void:
	var error := get_tree().change_scene_to_file(MAIN_SCENE_PATH)
	if error != OK:
		printerr("Error changing scene from Boot: ", error)
