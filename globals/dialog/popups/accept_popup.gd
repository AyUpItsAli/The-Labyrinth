class_name AcceptPopup extends DialogPopup

@export var max_width: float = 1000
@export var message_lbl: Label

func _ready() -> void:
	if message_lbl.size.x < max_width:
		message_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	else:
		message_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		custom_minimum_size.x = max_width

func _on_accept_btn_pressed() -> void:
	close()
