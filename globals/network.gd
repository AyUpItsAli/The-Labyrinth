extends Node

enum LobbyAccess { INVITE, FRIENDS, PUBLIC, INVISIBLE }

var peer: MultiplayerPeer = OfflineMultiplayerPeer.new()
var lobby_id: int

signal connection_successful
signal player_connected(player: Player)
signal player_disconnected(player: Player)
signal connection_closed

func _ready() -> void:
	Global.game_closed.connect(_on_game_closed)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.network_connection_status_changed.connect(_on_connection_status_changed)
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

func create_lobby(lobby_name: String) -> void:
	if get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING:
		Feedback.display_error("Error creating lobby: You are already connecting to a server")
		return
	if get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		Feedback.display_error("Error creating lobby: You are already connected to a server")
		return
	Logging.log_start("Creating lobby: %s" % lobby_name)
	await Loading.display_message("Creating lobby")
	Steam.createLobby(LobbyAccess.PUBLIC, 4) # TODO: Lobby settings
	for connection: Dictionary in Steam.lobby_created.get_connections():
		Steam.lobby_created.disconnect(connection.callable)
	Steam.lobby_created.connect(
		func(response: int, new_lobby_id: int) -> void:
			if response != Steam.RESULT_OK:
				Feedback.display_error("Error creating lobby: %s" % response)
				Loading.finish()
				return
			Steam.setLobbyData(new_lobby_id, "app_name", Global.app_name)
			Steam.setLobbyData(new_lobby_id, "app_version", Global.app_version)
			Steam.setLobbyData(new_lobby_id, "name", lobby_name)
			Logging.log_info("Lobby created: %s" % new_lobby_id)
	)

func join_lobby(id: int) -> void:
	if get_lobby_data_by_id(id, "app_name") != Global.app_name:
		Feedback.display_error("Error joining lobby: Lobby is not compatible with this application")
		return
	var app_version: String = get_lobby_data_by_id(id, "app_version", "???")
	if Global.app_version != app_version:
		Feedback.display_error("Error joining lobby: Your game version (%s) is not compatible with the host's game version (%s)" % [Global.app_version, app_version])
		return
	if get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING:
		Feedback.display_error("Error joining lobby: You are already connecting to a server")
		return
	if get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		Feedback.display_error("Error joining lobby: You are already connected to a server")
		return
	Logging.log_start("Joining lobby: %s" % id)
	await Loading.display_message("Joining lobby")
	Steam.joinLobby(id)

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
		Feedback.display_error("Error joining lobby: %s" % reason)
		Loading.finish()
		return
	lobby_id = id
	Logging.log_info("Joined lobby: %s" % lobby_id)
	await Loading.display_message("Loading lobby")
	await Loading.load_scene(Loading.Scene.LOBBY, false)
	create_peer()
	if multiplayer.is_server():
		GameState.register_player(GameState.player)
		Logging.log_success("Server created")
		connection_successful.emit()
	else:
		Logging.log_start("Connecting to server")
		await Loading.display_message("Connecting to server")

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
	Logging.log_start("Waiting for server")
	await Loading.display_message("Waiting for server")
	peer_connected.rpc_id(1, GameState.player.serialised())

@rpc("any_peer", "call_remote", "reliable")
func peer_connected(player_data: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var player := Player.deserialised(player_data)
	GameState.register_player(player)
	confirm_connection.rpc_id(player.id)
	Logging.log_success("%s connected" % player.name)
	player_connected.emit(player)

func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
	var player: Player = GameState.get_player(id)
	GameState.unregister_player(player)
	Logging.log_closure("%s disconnected" % player.name)
	player_disconnected.emit(player)

@rpc("authority", "call_remote", "reliable")
func confirm_connection() -> void:
	Logging.log_success("Connection successful")
	connection_successful.emit()

func _on_connection_successful() -> void:
	Loading.finish()

func _on_connection_status_changed(_handle: int, connection: Dictionary, _old_state: int) -> void:
	if connection.end_reason == Steam.NetworkingConnectionEnd.CONNECTION_END_MISC_TIMEOUT:
		Feedback.display_error(connection.end_debug)
		close_connection()

func _on_connection_failed() -> void:
	Feedback.display_error("Error connecting to server")
	close_connection()

func leave_server() -> void:
	if get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		Feedback.display_error("Error leaving server: You are not currently connected to a server")
		return
	Logging.log_start("Leaving server")
	close_connection()
	await Loading.loading_complete
	Feedback.display_message("Left server")

func _on_server_disconnected() -> void:
	Logging.log_closure("Server closed")
	close_connection()
	await Loading.loading_complete
	Feedback.display_message("Server closed")

func _on_game_closed() -> void:
	if get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
		close_connection()

func close_connection() -> void:
	peer.close()
	peer = OfflineMultiplayerPeer.new()
	multiplayer.set_multiplayer_peer(peer)
	Steam.leaveLobby(lobby_id)
	lobby_id = 0
	GameState.reset()
	Logging.log_closure("Connection closed")
	await Loading.load_scene(Loading.Scene.MENU)
	connection_closed.emit()
