extends CanvasLayer

const ACCEPT_POPUP = preload("res://globals/dialog/popups/accept_popup.tscn")
const INVITE_POPUP = preload("res://globals/dialog/popups/invite_popup.tscn")

@export var popup_container: Container

func _ready() -> void:
	visible = popup_container.get_child_count() > 0

func display_popup(popup: DialogPopup) -> void:
	show()
	popup.tree_exited.connect(_on_popup_closed)
	popup_container.add_child(popup)

func _on_popup_closed() -> void:
	visible = popup_container.get_child_count() > 0

func display_message(message: String) -> void:
	var popup: AcceptPopup = ACCEPT_POPUP.instantiate()
	popup.message_lbl.text = message
	display_popup(popup)

func display_error(message: String, log_error: bool = false) -> void:
	if log_error:
		Logging.log_error(message)
	var popup: AcceptPopup = ACCEPT_POPUP.instantiate()
	popup.message_lbl.text = message
	popup.message_lbl.modulate = Color("ff5c5c")
	display_popup(popup)

func display_invite_popup() -> void:
	display_popup(INVITE_POPUP.instantiate())
