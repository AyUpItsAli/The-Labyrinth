extends Node3D

@export var board: Board

func _ready() -> void:
	board.generate()
	Overlay.finish_loading()
