class_name DialogPopup extends Control

var previous_focus_owner: Control

func _ready() -> void:
	previous_focus_owner = get_viewport().gui_get_focus_owner()
	set_focus_mode(Control.FOCUS_CLICK)
	grab_focus()

func close() -> void:
	if previous_focus_owner:
		previous_focus_owner.grab_focus()
	queue_free()
