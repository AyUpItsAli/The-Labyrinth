class_name FeedbackPopup extends Control

@export var message_lbl: Label

func close() -> void:
	queue_free()
