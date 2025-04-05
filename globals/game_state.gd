extends Node

const MAX_CHAT_MESSAGES = 100
const HOST_COLOUR = "crimson"

enum MessageType { PLAYER, SERVER }

var player: Player
var players: Dictionary
var chat: Array[Dictionary]

signal players_updated
signal chat_updated

func _ready() -> void:
	Steam.avatar_loaded.connect(_on_avatar_loaded)
	Network.server_created.connect(_on_server_created)
	Network.player_connected.connect(_on_player_connected)
	Network.player_disconnected.connect(_on_player_disconnected)
	reset()

func reset() -> void:
	player = Player.new()
	player.steam_id = Global.steam_id
	player.name = Global.steam_username
	Steam.getPlayerAvatar(Steam.AVATAR_LARGE)
	players.clear()
	chat.clear()

func _on_avatar_loaded(id: int, icon_size: int, bytes: PackedByteArray) -> void:
	if player.icon:
		return
	if id != player.steam_id:
		return
	player.icon = Player.load_icon(icon_size, bytes)

func serialised() -> Dictionary:
	var data: Dictionary = {}
	data["players"] = get_players_serialised()
	data["chat"] = chat
	return data

func update(data: Dictionary) -> void:
	Logging.log_info("Updating game state")
	update_players(data["players"])
	chat = data["chat"]
	chat_updated.emit()

# ---------
# PLAYERS
# ---------

func get_player(id: int) -> Player:
	return players[id]

func get_players_sorted() -> Array:
	var sorted: Array = players.values()
	sorted.sort_custom(func(plr1: Player, plr2: Player) -> bool: return plr1.index < plr2.index)
	return sorted

func get_players_serialised() -> Array[Dictionary]:
	var player_data: Array[Dictionary] = []
	for plr: Player in players.values():
		player_data.append(plr.serialised())
	return player_data

@rpc("authority", "call_remote", "reliable")
func update_players(player_data: Array[Dictionary]) -> void:
	Logging.log_info("Updating players")
	players.clear()
	for data: Dictionary in player_data:
		var new_player := Player.deserialised(data)
		if player.id == new_player.id:
			player = new_player
		players[new_player.id] = new_player
	players_updated.emit()

func register_player(new_player: Player) -> void:
	if multiplayer.is_server():
		# Server-side setup for new players
		new_player.index = players.size()
		# Register for clients
		register_player_serialised.rpc(new_player.serialised())
	# Register player
	players[new_player.id] = new_player
	Logging.log_info("Registered player: ID = %s, Name: %s" % [new_player.id, new_player.name])
	players_updated.emit()

@rpc("authority", "call_remote", "reliable")
func register_player_serialised(player_data: Dictionary) -> void:
	register_player(Player.deserialised(player_data))

func unregister_player(old_player: Player) -> void:
	# Remove player
	players.erase(old_player.id)
	# Ensure remaining players have the correct index
	var index: int = 0
	for plr: Player in get_players_sorted():
		plr.index = index
		index += 1
	# Update clients
	update_players.rpc(get_players_serialised())
	Logging.log_info("Unregistered player: ID = %s, Name: %s" % [old_player.id, old_player.name])
	players_updated.emit()

# ------
# CHAT
# ------

@rpc("authority", "call_remote", "reliable", Network.Channel.CHAT)
func register_chat_message(msg: Dictionary) -> void:
	if multiplayer.is_server():
		# Timestamp and index determined by server
		msg["time"] = Time.get_unix_time_from_system()
		msg["index"] = chat.size()
		# Register for clients
		register_chat_message.rpc(msg)
	# Insert message
	chat.insert(msg["index"], msg)
	if chat.size() > MAX_CHAT_MESSAGES:
		chat.pop_front()
	chat_updated.emit()

@rpc("any_peer", "call_local", "reliable", Network.Channel.CHAT)
func receive_player_message(content: String) -> void:
	if not multiplayer.is_server():
		return
	var sender: Player = GameState.get_player(multiplayer.get_remote_sender_id())
	var msg: Dictionary = {}
	msg["type"] = MessageType.PLAYER
	var name_colour: String = HOST_COLOUR if sender.is_host() else "white"
	msg["content"] = "[color=%s]%s:[/color] %s" % [name_colour, sender.name, content]
	register_chat_message(msg)

func send_player_message(content: String) -> void:
	content = content.strip_edges()
	if content.is_empty():
		return
	if Network.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		Overlay.display_error_popup("Error sending chat message: You are not currently connected to a server")
		return
	receive_player_message.rpc_id(1, content)

func send_server_message(content: String) -> void:
	# Server-side only
	if not multiplayer.is_server():
		return
	var msg: Dictionary = {}
	msg["type"] = MessageType.SERVER
	msg["content"] = content
	register_chat_message(msg)

func _on_server_created() -> void:
	send_server_message("[color=cyan]Server Created[/color]")

func _on_player_connected(new_player: Player) -> void:
	send_server_message("[color=green]%s joined[/color]" % new_player.name)

func _on_player_disconnected(old_player: Player) -> void:
	send_server_message("[color=red]%s left[/color]" % old_player.name)
