class_name FeedbackPopup extends Control

@export var message_lbl: Label

var previous_focus_owner: Control

func _ready() -> void:
	previous_focus_owner = get_viewport().gui_get_focus_owner()
	set_focus_mode(Control.FOCUS_ALL)
	grab_focus()

func close() -> void:
	if previous_focus_owner:
		previous_focus_owner.grab_focus()
	queue_free()
