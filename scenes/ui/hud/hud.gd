extends CanvasLayer

@export_group("Chat")
@export var chat_btn: BaseButton
@export var chat: Container

func _ready() -> void:
	update_chat()

func _on_chat_btn_pressed() -> void:
	update_chat()

func update_chat() -> void:
	chat.visible = chat_btn.button_pressed
