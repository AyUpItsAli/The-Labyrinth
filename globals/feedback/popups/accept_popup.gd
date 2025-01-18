class_name AcceptPopup extends FeedbackPopup

@export var accept_btn: Button

func _ready() -> void:
	accept_btn.pressed.connect(_on_accept_btn_pressed)

func _on_accept_btn_pressed() -> void:
	close()
