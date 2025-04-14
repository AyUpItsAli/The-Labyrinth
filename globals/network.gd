extends Node

enum Channel { DEFAULT, CHAT }

var peer: MultiplayerPeer = OfflineMultiplayerPeer.new()
var lobby_id: int = -1

var acknowledgements: Dictionary[String, Dictionary]

signal server_created
signal connection_successful
signal player_connected(player: Player)
signal player_disconnected(player: Player)
signal ack_confirmed(id: String)

func _ready() -> void:
	Global.game_closed.connect(_on_game_closed)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.network_connection_status_changed.connect(_on_connection_status_changed)
	Steam.join_requested.connect(_on_lobby_join_requested)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	connection_successful.connect(_on_connection_successful)

func get_lobby_data_by_id(id: int, key: String, default: String = "") -> String:
	var data: String = Steam.getLobbyData(id, key)
	if data.is_empty():
		return default
	return data

func get_lobby_data(key: String, default: String = "") -> String:
	return get_lobby_data_by_id(lobby_id, key, default)

func get_connection_status() -> MultiplayerPeer.ConnectionStatus:
	if peer is OfflineMultiplayerPeer:
		return MultiplayerPeer.ConnectionStatus.CONNECTION_DISCONNECTED
	return peer.get_connection_status()

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
			Utils.log_info("Lobby created: %s" % new_lobby_id)
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
	Utils.log_info("Joined lobby: %s" % lobby_id)
	create_peer()
	if multiplayer.is_server():
		GameState.register_player(GameState.player)
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
	if host_id == Global.steam_id:
		peer.create_host(0)
	else:
		peer.create_client(host_id, 0)
	multiplayer.set_multiplayer_peer(peer)
	GameState.player.id = multiplayer.get_unique_id()

func _on_connected_to_server() -> void:
	# Forward local player data to server
	peer_connected.rpc_id(1, GameState.player.serialised())
	# Wait for server to confirm connection
	Utils.log_start("Waiting for server")
	await Overlay.display_loading_message("Waiting for server")

@rpc("any_peer", "call_remote", "reliable")
func peer_connected(player_data: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	# Register connected player
	var player := Player.deserialised(player_data)
	GameState.register_player(player)
	# Confirm connection for connected player and forward our game data
	confirm_connection.rpc_id(player.id, GameState.serialised())
	player_connected.emit(player)

@rpc("authority", "call_remote", "reliable")
func confirm_connection(data: Dictionary) -> void:
	# Load game state using data received from server
	GameState.load_data(data)
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
	peer.close()
	peer = OfflineMultiplayerPeer.new()
	multiplayer.set_multiplayer_peer(peer)
	Steam.leaveLobby(lobby_id)
	lobby_id = -1
	acknowledgements.clear()
	GameState.reset()
	Utils.log_closure("Connection closed")
	Loading.load_scene(Loading.Scene.MENU)

func _on_peer_disconnected(id: int) -> void:
	# Server-side only
	if not multiplayer.is_server():
		return
	var player: Player = GameState.unregister_player(id)
	player_disconnected.emit(player)

# -----------------
# ACKNOWLEDGEMENTS
# -----------------

func get_ack(id: String) -> Dictionary:
	return acknowledgements.get_or_add(id, {"ids": {}, "queried": false})

## Emits "ack_confirmed" if the given acknowledgement has been queried
## and all peers have been registered to the ack
func check_ack(id: String) -> void:
	var ack: Dictionary = get_ack(id)
	if ack.get("queried") and ack.get("ids").has_all(multiplayer.get_peers()):
		Utils.log_info("Confirmed acknowledgement \"%s\" for all players" % id)
		ack_confirmed.emit(id)
		acknowledgements.erase(id)

@rpc("any_peer", "call_remote", "reliable")
## Registers the sender for the given acknowledgement, then checks the ack
func register_ack(id: String) -> void:
	var ack: Dictionary = get_ack(id)
	# Add sender's id to set of ids
	var sender: int = multiplayer.get_remote_sender_id()
	ack.get("ids").set(sender, null)
	Utils.log_info("Recieved acknowledgement \"%s\" from %s" % [id, sender])
	# Check acknowledgement
	check_ack(id)

## Registers the sender for an acknowledgement to the server
func register_server_ack(id: String) -> void:
	register_ack.rpc_id(1, id)

## Marks an acknowledgement as queried, then checks the ack
func query_ack(id: String) -> void:
	Utils.log_info("Querying acknowledgement \"%s\"" % id)
	get_ack(id).set("queried", true)
	check_ack(id)
