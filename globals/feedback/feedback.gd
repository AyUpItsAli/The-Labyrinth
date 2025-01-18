extends CanvasLayer

const ACCEPT_POPUP = preload("res://globals/feedback/popups/accept_popup.tscn")

@export var popup_container: Container

func _ready() -> void:
	visible = popup_container.get_child_count() > 0

func display_error(message: String) -> void:
	Logging.log_error(message)
	var popup: AcceptPopup = ACCEPT_POPUP.instantiate()
	popup.message_lbl.text = message
	if not popup.message_lbl.label_settings:
		popup.message_lbl.label_settings = LabelSettings.new()
	popup.message_lbl.label_settings.font_color = Color("ff5c5c")
	display_popup(popup)

func display_message(message: String) -> void:
	var popup: AcceptPopup = ACCEPT_POPUP.instantiate()
	popup.message_lbl.text = message
	display_popup(popup)

func display_popup(popup: FeedbackPopup) -> void:
	show()
	popup.tree_exited.connect(_on_popup_closed)
	popup_container.add_child(popup)

func _on_popup_closed() -> void:
	visible = popup_container.get_child_count() > 0
