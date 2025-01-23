extends Control

const CHAT_MESSAGE = preload("res://scenes/ui/chat/chat_message.tscn")

@export var lobby_name_lbl: Label
@export var player_list: ItemList
@export var start_btn: Button
@export var chat_container: ScrollContainer
@export var message_container: Container
@export var message_edit: LineEdit

func _ready() -> void:
	Network.connection_successful.connect(_on_connection_successful)
	GameState.players_updated.connect(_on_players_updated)
	GameState.chat_updated.connect(_on_chat_updated)
	player_list.clear()
	clear_chat()
	message_edit.grab_focus()

func _on_connection_successful() -> void:
	lobby_name_lbl.set_text("Lobby: %s" % Network.get_lobby_data("name", "???"))
	start_btn.set_disabled(not multiplayer.is_server())
	Loading.finish()

func _on_players_updated() -> void:
	player_list.clear()
	for player: Player in GameState.get_players_sorted():
		player_list.add_item(player.name, player.icon)

func clear_chat() -> void:
	for child in message_container.get_children():
		child.queue_free()

func _on_chat_updated() -> void:
	clear_chat()
	for msg: Dictionary in GameState.chat:
		var message: ChatMessage = CHAT_MESSAGE.instantiate()
		match msg["type"]:
			GameState.MessageType.SERVER:
				message.content_lbl.text = "[center]%s[/center]" % msg["content"]
				message.timestamp_lbl.hide()
			_:
				message.content_lbl.text = msg["content"]
				var time: Dictionary = Time.get_time_dict_from_unix_time(msg["time"])
				message.timestamp_lbl.text = "%02d:%02d" % [time["hour"], time["minute"]]
		message_container.add_child(message)
	# No idea why we need to wait 2 frames, instead of 1, before setting scroll
	await get_tree().process_frame
	await get_tree().process_frame
	# Scroll to end
	chat_container.set_v_scroll(Vector2i.MAX.x)

func _on_message_edit_text_submitted(content: String) -> void:
	message_edit.clear()
	GameState.send_player_message(content)

func _on_leave_btn_pressed() -> void:
	Network.leave_server()
