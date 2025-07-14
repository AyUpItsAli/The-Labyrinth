extends Node

const MIN_PLAYERS = 1 # TODO: Actual value should be 2
const MAX_CHAT_MESSAGES = 100
const HOST_COLOUR = "crimson"

enum Channel { DEFAULT, CHAT }
enum MessageType { PLAYER, NETWORK }

var peer: MultiplayerPeer = OfflineMultiplayerPeer.new()
var lobby_id: int = -1
var players: Dictionary[int, Player]
var chat: Array[Dictionary]
var acknowledgements: Dictionary[String, Dictionary]

signal server_created
signal connection_successful
signal player_connected(player: Player)
signal player_disconnected(player: Player)
signal ack_resolved(id: String)
signal players_updated
signal chat_updated

func _ready() -> void:
	Global.game_closed.connect(_on_game_closed)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.network_connection_status_changed.connect(_on_connection_status_changed)
	Steam.join_requested.connect(_on_lobby_join_requested)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	server_created.connect(_on_server_created)
	connection_successful.connect(_on_connection_successful)
	player_connected.connect(_on_player_connected)
	player_disconnected.connect(_on_player_disconnected)

func reset() -> void:
	# Peer
	peer.close()
	peer = OfflineMultiplayerPeer.new()
	multiplayer.set_multiplayer_peer(peer)
	# Lobby
	Steam.leaveLobby(lobby_id)
	lobby_id = -1
	players.clear()
	chat.clear()
	acknowledgements.clear()

func serialised() -> Dictionary:
	var data: Dictionary = {}
	data.set("players", get_players_serialised())
	data.set("chat", chat)
	return data

func load_data(data: Dictionary) -> void:
	update_players(data.get("players"))
	chat = data.get("chat")
	chat_updated.emit()

func get_connection_status() -> MultiplayerPeer.ConnectionStatus:
	if peer is OfflineMultiplayerPeer:
		return MultiplayerPeer.ConnectionStatus.CONNECTION_DISCONNECTED
	return peer.get_connection_status()

func get_lobby_data_by_id(id: int, key: String, default: String = "") -> String:
	var data: String = Steam.getLobbyData(id, key)
	if data.is_empty():
		return default
	return data

func get_lobby_data(key: String, default: String = "") -> String:
	return get_lobby_data_by_id(lobby_id, key, default)

# --------
# PLAYERS
# --------

func get_players_sorted() -> Array:
	var sorted: Array = players.values()
	sorted.sort_custom(
		func(a: Player, b: Player) -> bool:
			return a.index < b.index
	)
	return sorted

func get_players_serialised() -> Array[Dictionary]:
	var data: Array[Dictionary] = []
	for player: Player in players.values():
		data.append(player.serialised())
	return data

func players_ready() -> bool:
	if Network.players.size() < MIN_PLAYERS:
		return false
	for player: Player in players.values():
		if not player.ready:
			return false
	return true

@rpc("authority", "call_remote", "reliable")
func update_players(data: Array[Dictionary]) -> void:
	Utils.log_info("Updating players")
	players.clear()
	for player_data: Dictionary in data:
		var player := Player.deserialised(player_data)
		if player.id == Global.player.id:
			Global.player = player
		players[player.id] = player
	players_updated.emit()

func register_player(player: Player) -> void:
	if player.is_host():
		player.ready = true
	if multiplayer.is_server():
		# Server-side setup for new players
		player.index = players.size()
		# Register for clients
		register_player_serialised.rpc(player.serialised())
	# Register player
	players[player.id] = player
	Utils.log_info("Registered player: ID = %s, Name: %s" % [player.id, player.display_name])
	players_updated.emit()

@rpc("authority", "call_remote", "reliable")
func register_player_serialised(player_data: Dictionary) -> void:
	register_player(Player.deserialised(player_data))

func unregister_player(id: int) -> Player:
	# Get the player to remove
	var removed: Player = players.get(id)
	# Remove player
	players.erase(id)
	# Ensure remaining players have the correct index
	var index: int = 0
	for player: Player in get_players_sorted():
		player.index = index
		index += 1
	# Update clients
	update_players.rpc(get_players_serialised())
	Utils.log_info("Unregistered player: ID = %s, Name: %s" % [id, removed.display_name])
	players_updated.emit()
	return removed

@rpc("any_peer", "call_local", "reliable")
func set_player_ready(id: int, player_ready: bool) -> void:
	var player: Player = players.get(id)
	player.ready = player_ready
	players_updated.emit()

# -----
# CHAT
# -----

@rpc("authority", "call_remote", "reliable", Network.Channel.CHAT)
func register_chat_message(msg: Dictionary) -> void:
	if multiplayer.is_server():
		# Timestamp and index determined by server
		msg.set("time", Time.get_unix_time_from_system())
		msg.set("index", chat.size())
		# Register for clients
		register_chat_message.rpc(msg)
	# Insert message
	chat.insert(msg.get("index"), msg)
	if chat.size() > MAX_CHAT_MESSAGES:
		chat.pop_front()
	chat_updated.emit()

@rpc("any_peer", "call_remote", "reliable", Network.Channel.CHAT)
func receive_player_message(content: String) -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = Global.player.id
	var player: Player = players.get(sender)
	var msg: Dictionary = {}
	msg.set("type", MessageType.PLAYER)
	var name_colour: String = HOST_COLOUR if player.is_host() else "white"
	msg.set("content", "[color=%s]%s:[/color] %s" % [name_colour, player.display_name, content])
	register_chat_message(msg)

func send_player_message(content: String) -> void:
	content = content.strip_edges()
	if content.is_empty():
		return
	if Network.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		Overlay.display_error("Error sending chat message: You are not currently connected to a server")
		return
	# TODO: Refactor
	if multiplayer.is_server():
		receive_player_message(content)
	else:
		receive_player_message.rpc_id(1, content)

func send_network_message(content: String) -> void:
	# Server-side only
	if not multiplayer.is_server():
		return
	var msg: Dictionary = {}
	msg.set("type", MessageType.NETWORK)
	msg.set("content", content)
	register_chat_message(msg)

func _on_server_created() -> void:
	send_network_message("[color=cyan]Welcome to the lobby[/color]")

func _on_player_connected(player: Player) -> void:
	send_network_message("[color=green]%s joined[/color]" % player.display_name)

func _on_player_disconnected(player: Player) -> void:
	send_network_message("[color=red]%s left[/color]" % player.display_name)

# ----------------------------
# CREATING / JOINING LOBBY
# ----------------------------

func create_lobby(settings: GameSettings) -> void:
	if not Global.steam_initialised:
		Overlay.display_error("Error creating lobby: Steam is not initialised")
		return
	if get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING:
		Overlay.display_error("Error creating lobby: You are already connecting to a server")
		return
	if get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		Overlay.display_error("Error creating lobby: You are already connected to a server")
		return
	Utils.log_start("Creating lobby: Name = %s, Type = %s" % [settings.lobby_name, GameSettings.LOBBY_TYPES.get(settings.lobby_type)])
	await Overlay.display_loading_message("Creating lobby")
	Steam.createLobby(settings.lobby_type, settings.max_players)
	for connection: Dictionary in Steam.lobby_created.get_connections():
		Steam.lobby_created.disconnect(connection.callable)
	Steam.lobby_created.connect(
		func(response: int, new_lobby_id: int) -> void:
			if response != Steam.RESULT_OK:
				Overlay.display_error("Error creating lobby: %s" % response, true)
				Overlay.finish_loading()
				return
			Steam.setLobbyData(new_lobby_id, "app_name", Global.app_name)
			Steam.setLobbyData(new_lobby_id, "app_version", Global.app_version)
			Steam.setLobbyData(new_lobby_id, "name", settings.lobby_name)
			Utils.log_success("Lobby created: %s" % new_lobby_id)
	)

func join_lobby(id: int) -> void:
	if not Global.steam_initialised:
		Overlay.display_error("Error joining lobby: Steam is not initialised")
		return
	if get_lobby_data_by_id(id, "app_name") != Global.app_name:
		Overlay.display_error("Error joining lobby: Lobby is not compatible with this application")
		return
	var app_version: String = get_lobby_data_by_id(id, "app_version", "???")
	if Global.app_version != app_version:
		Overlay.display_error("Error joining lobby: Your game version (%s) is not compatible with the host's game version (%s)" % [Global.app_version, app_version])
		return
	if get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING:
		Overlay.display_error("Error joining lobby: You are already connecting to a server")
		return
	if get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		Overlay.display_error("Error joining lobby: You are already connected to a server")
		return
	Utils.log_start("Joining lobby: %s" % id)
	await Overlay.display_loading_message("Joining lobby")
	Steam.joinLobby(id)

func _on_lobby_join_requested(id: int, _friend_id: int) -> void:
	Steam.requestLobbyData(id)
	await Steam.lobby_data_update
	join_lobby(id)

func _on_lobby_joined(id: int, _perms: int, _locked: bool, response: int) -> void:
	if response != Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		var reason: String = "Reason unknown"
		match response:
			Steam.CHAT_ROOM_ENTER_RESPONSE_DOESNT_EXIST:
				reason = "This lobby no longer exists"
			Steam.CHAT_ROOM_ENTER_RESPONSE_NOT_ALLOWED:
				reason = "You don't have permission to join this lobby"
			Steam.CHAT_ROOM_ENTER_RESPONSE_FULL:
				reason = "The lobby is now full"
			Steam.CHAT_ROOM_ENTER_RESPONSE_ERROR:
				reason = "Something unexpected happened"
			Steam.CHAT_ROOM_ENTER_RESPONSE_BANNED:
				reason = "You are banned from this lobby"
			Steam.CHAT_ROOM_ENTER_RESPONSE_LIMITED:
				reason = "You cannot join due to having a limited account"
			Steam.CHAT_ROOM_ENTER_RESPONSE_CLAN_DISABLED:
				reason = "This lobby is locked or disabled"
			Steam.CHAT_ROOM_ENTER_RESPONSE_COMMUNITY_BAN:
				reason = "This lobby is community locked"
			Steam.CHAT_ROOM_ENTER_RESPONSE_MEMBER_BLOCKED_YOU:
				reason = "A user in the lobby has blocked you from joining"
			Steam.CHAT_ROOM_ENTER_RESPONSE_YOU_BLOCKED_MEMBER:
				reason = "A user you have blocked is in the lobby"
		Overlay.display_error("Error joining lobby: %s" % reason, true)
		Overlay.finish_loading()
		return
	lobby_id = id
	Utils.log_success("Joined lobby: %s" % lobby_id)
	create_peer()
	if multiplayer.is_server():
		register_player(Global.player)
		Utils.log_success("Server created")
		server_created.emit()
		connection_successful.emit()
	else:
		Utils.log_start("Connecting to server")
		await Overlay.display_loading_message("Connecting to server")

# ------------------------
# CONNECTING TO SERVER
# ------------------------

func create_peer() -> void:
	peer = SteamMultiplayerPeer.new()
	var host_id: int = Steam.getLobbyOwner(lobby_id)
	if host_id == Global.player.steam_id:
		peer.create_host(0)
	else:
		peer.create_client(host_id, 0)
	multiplayer.set_multiplayer_peer(peer)
	Global.player.id = multiplayer.get_unique_id()

func _on_connected_to_server() -> void:
	# Forward local player data to server
	peer_connected.rpc_id(1, Global.player.serialised())
	# Wait for server to confirm connection
	Utils.log_start("Waiting for server")
	await Overlay.display_loading_message("Waiting for server")

@rpc("any_peer", "call_remote", "reliable")
func peer_connected(player_data: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	# Register connected player
	var player := Player.deserialised(player_data)
	register_player(player)
	# Forward network data to connected player
	confirm_connection.rpc_id(player.id, serialised())
	Utils.log_success("%s connected" % player.display_name)
	player_connected.emit(player)

@rpc("authority", "call_remote", "reliable")
func confirm_connection(data: Dictionary) -> void:
	# Load network data received from server
	load_data(data)
	Utils.log_success("Connection successful")
	connection_successful.emit()

func _on_connection_successful() -> void:
	Utils.log_start("Loading lobby")
	await Overlay.display_loading_message("Loading lobby")
	Loading.load_scene(Loading.Scene.LOBBY)

func _on_connection_status_changed(_handle: int, connection: Dictionary, _old_state: int) -> void:
	if connection.end_reason == Steam.NetworkingConnectionEnd.CONNECTION_END_MISC_TIMEOUT:
		Overlay.display_error(connection.end_debug, true)
		close_connection()

func _on_connection_failed() -> void:
	Overlay.display_error("Error connecting to server", true)
	close_connection()

# -----------------------------
# DISCONNECTING FROM SERVER
# -----------------------------

func leave_server() -> void:
	if get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		Overlay.display_error("Error leaving server: You are not currently connected to a server")
		return
	Utils.log_start("Leaving server")
	close_connection()
	await Loading.loading_complete
	Overlay.display_message("Left server")

func _on_server_disconnected() -> void:
	Utils.log_closure("Server disconnected")
	close_connection()
	await Loading.loading_complete
	Overlay.display_error("Server disconnected")

func _on_game_closed() -> void:
	if get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
		close_connection()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("close_connection") and get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
		close_connection()

func close_connection() -> void:
	Global.reset()
	Utils.log_closure("Connection closed")
	Loading.load_scene(Loading.Scene.MENU)

func _on_peer_disconnected(id: int) -> void:
	# Server-side only
	if not multiplayer.is_server():
		return
	var player: Player = unregister_player(id)
	Utils.log_closure("%s disconnected" % player.display_name)
	player_disconnected.emit(player)

# -----------------
# ACKNOWLEDGEMENTS
# -----------------

func get_ack(id: String) -> Dictionary:
	return acknowledgements.get_or_add(id, {})

@rpc("any_peer", "call_remote", "reliable")
func register_ack(id: String, from: int) -> void:
	var ack: Dictionary = get_ack(id)
	ack.set(from, true)
	Utils.log_info("Recieved acknowledgement \"%s\" from %s" % [id, from])
	# Once all players have been registered, resolve the acknowledgement
	if ack.has_all(players.keys()):
		Utils.log_info("Resolving acknowledgement \"%s\"" % id)
		acknowledgements.erase(id)
		ack_resolved.emit(id)

func send_ack(id: String, to: int = 0) -> void:
	if to == 0 or to == Global.player.id:
		register_ack(id, Global.player.id)
	else:
		register_ack.rpc_id(to, id, Global.player.id)
