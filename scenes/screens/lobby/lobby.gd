extends Control

const CHAT_MESSAGE = preload("res://scenes/ui/chat/chat_message.tscn")

@export var lobby_title_lbl: Label
@export var invite_btn: Button
@export var player_list: ItemList
@export var start_btn: Button
@export var chat_container: ScrollContainer
@export var message_container: Container
@export var message_edit: LineEdit

func _ready() -> void:
	GameState.players_updated.connect(update_players)
	GameState.chat_updated.connect(update_chat)
	invite_btn.set_visible(multiplayer.is_server())
	start_btn.set_visible(multiplayer.is_server())
	message_edit.grab_focus()
	update_players()
	update_chat()

func update_players() -> void:
	# Update lobby title with new player count
	var lobby_name: String = Network.get_lobby_data("name", "???")
	var member_count: int = Network.get_lobby_member_count()
	var max_members: int = Network.get_lobby_max_members()
	lobby_title_lbl.set_text("Lobby: %s | %s/%s" % [lobby_name, member_count, max_members])
	# Update player list
	player_list.clear()
	for player: Player in GameState.get_players_sorted():
		var i: int = player_list.add_item(player.name, player.icon, false)
		player_list.set_item_tooltip_enabled(i, false)

func update_chat() -> void:
	for child in message_container.get_children():
		child.queue_free()
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

func _on_invite_btn_pressed() -> void:
	Dialog.display_invite_popup()

func _on_message_edit_text_submitted(content: String) -> void:
	message_edit.clear()
	GameState.send_player_message(content)

func _on_leave_btn_pressed() -> void:
	Network.leave_server()
