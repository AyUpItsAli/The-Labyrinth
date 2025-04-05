class_name MessagePopup extends OverlayPopup

@export var message_lbl: Label
@export var max_width: float = 1000

func _ready() -> void:
	if message_lbl.size.x < max_width:
		message_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	else:
		message_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		custom_minimum_size.x = max_width

func _on_ok_btn_pressed() -> void:
	close()
