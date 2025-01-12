extends Control

@export var lobby_name_lbl: Label
@export var player_list: ItemList
@export var start_btn: Button
@export var chat_box: RichTextLabel
@export var message_edit: LineEdit

func _ready() -> void:
	Network.player_connected.connect(_on_player_connected)
	Network.player_disconnected.connect(_on_player_disconnected)
	Network.connection_closed.connect(_on_connection_closed)
	GameState.players_updated.connect(update_player_list)
	lobby_name_lbl.set_text("Lobby: %s" % Network.get_lobby_data("name", "???"))
	start_btn.set_disabled(not multiplayer.is_server())
	message_edit.grab_focus()
	update_player_list()
	if not multiplayer.is_server():
		request_chat_update.rpc_id(1)

func _on_quit_btn_pressed() -> void:
	Global.quit_game()

func update_player_list() -> void:
	player_list.clear()
	for player: Player in GameState.get_players_sorted():
		player_list.add_item(player.name, player.icon)

func _on_message_edit_text_submitted(message: String) -> void:
	if message.is_empty():
		return
	message_edit.clear()
	if Network.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	send_chat_message.rpc_id(1, message)

@rpc("any_peer", "call_local", "reliable")
func send_chat_message(message: String) -> void:
	if not multiplayer.is_server():
		return
	var sent_by: int = multiplayer.get_remote_sender_id()
	var player: Player = GameState.get_player(sent_by)
	chat_box.text += "[color=white]%s:[/color] %s\n" % [player.name, message]
	update_chat.rpc(chat_box.text)

func _on_player_connected(player: Player) -> void:
	if not multiplayer.is_server():
		return
	chat_box.text += "[color=green]%s joined[/color]\n" % player.name
	update_chat.rpc(chat_box.text)

func _on_player_disconnected(player: Player) -> void:
	if not multiplayer.is_server():
		return
	chat_box.text += "[color=red]%s left[/color]\n" % player.name
	update_chat.rpc(chat_box.text)

@rpc("any_peer", "call_remote", "reliable")
func request_chat_update() -> void:
	if not multiplayer.is_server():
		return
	var requested_by: int = multiplayer.get_remote_sender_id()
	update_chat.rpc_id(requested_by, chat_box.text)

# TODO: Fix: "Failed to get path from RPC" when client is connecting

@rpc("authority", "call_remote", "reliable")
func update_chat(text: String) -> void:
	chat_box.text = text

func _on_leave_btn_pressed() -> void:
	Network.leave_server()

func _on_connection_closed() -> void:
	LoadingScreen.load_scene("res://scenes/screens/menu/menu.tscn")
