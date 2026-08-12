class_name ToolTip
extends Control

@export var content: Label
@export var title: Label
@export var tool_tip_node: Control

func _ready() -> void:
	content.text = "content"
	title.text = "title"
	tool_tip_node.visible = false
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered() -> void:
	tool_tip_node.visible = true

func _on_mouse_exited() -> void:
	tool_tip_node.visible = false
