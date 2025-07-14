class_name ChatPanel extends PanelContainer

const CHAT_MESSAGE = preload("res://scenes/ui/chat/chat_message.tscn")

@export var message_edit: LineEdit
@export_group("Nodes")
@export var scroll_container: ScrollContainer
@export var message_container: Container

func _ready() -> void:
	Network.chat_updated.connect(refresh)
	message_edit.text_submitted.connect(_on_message_edit_text_submitted)
	refresh()

func refresh() -> void:
	for child in message_container.get_children():
		message_container.remove_child(child)
		child.queue_free()
	for msg: Dictionary in Network.chat:
		var message: ChatMessage = CHAT_MESSAGE.instantiate()
		match msg.get("type"):
			Network.MessageType.NETWORK:
				message.content_lbl.set_text("[center]%s[/center]" % msg.get("content"))
				message.timestamp_lbl.hide()
			_:
				message.content_lbl.set_text(msg.get("content"))
				var bias: int = Time.get_time_zone_from_system().get("bias")
				var unix_time: int = msg.get("time") + (bias * 60)
				var time: Dictionary = Time.get_time_dict_from_unix_time(unix_time)
				message.timestamp_lbl.set_text("%02d:%02d" % [time.get("hour"), time.get("minute")])
		message_container.add_child(message)
	# No idea why we need to wait 2 frames, instead of 1, before setting scroll
	await get_tree().process_frame
	await get_tree().process_frame
	# Scroll to end
	scroll_container.set_v_scroll(Vector2i.MAX.x)

func _on_message_edit_text_submitted(content: String) -> void:
	message_edit.clear()
	Network.send_player_message(content)
