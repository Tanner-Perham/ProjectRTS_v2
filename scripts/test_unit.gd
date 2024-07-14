extends Node3D

@onready var selected_graphic:Sprite3D = $selected

func _ready() -> void:
	unselected()

func selected() -> void:
	selected_graphic.visible = true

func unselected() -> void:
	selected_graphic.visible = false
