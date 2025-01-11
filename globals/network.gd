extends Node

enum LobbyAccess { INVITE, FRIENDS, PUBLIC, INVISIBLE }

var peer: MultiplayerPeer = OfflineMultiplayerPeer.new()
var lobby_id: int

signal connection_successful
signal connection_closed

func _ready() -> void:
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.network_connection_status_changed.connect(_on_connection_status_changed)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	Global.game_closed.connect(_on_game_closed)

func get_lobby_data(key: String, default: String = "") -> String:
	var data: String = Steam.getLobbyData(lobby_id, key)
	if data.is_empty():
		return default
	return data

func get_connection_status() -> MultiplayerPeer.ConnectionStatus:
	if peer is OfflineMultiplayerPeer:
		return MultiplayerPeer.ConnectionStatus.CONNECTION_DISCONNECTED
	return peer.get_connection_status()

func create_lobby(lobby_name: String) -> void:
	if get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING:
		Logging.log_error("Error creating lobby: You are already connecting to a server")
		return
	if get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		Logging.log_error("Error creating lobby: You are already connected to a server")
		return
	Logging.log_start("Creating lobby: %s" % lobby_name)
	Steam.createLobby(LobbyAccess.PUBLIC, 4) # TODO: Lobby settings
	for connection: Dictionary in Steam.lobby_created.get_connections():
		Steam.lobby_created.disconnect(connection.callable)
	Steam.lobby_created.connect(
		func(response: int, new_lobby_id: int) -> void:
			if response != Steam.RESULT_OK:
				Logging.log_error("Error creating lobby: %s" % response)
				return
			Steam.setLobbyData(new_lobby_id, "game_name", Global.GAME_NAME)
			Steam.setLobbyData(new_lobby_id, "name", lobby_name)
			Logging.log_info("Lobby created: %s" % new_lobby_id)
	)

func join_lobby(id: int) -> void:
	if Steam.getLobbyData(id, "game_name") != Global.GAME_NAME:
		Logging.log_error("Error joining lobby: Incompatible lobby")
		return
	if get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING:
		Logging.log_error("Error joining lobby: You are already connecting to a server")
		return
	if get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		Logging.log_error("Error joining lobby: You are already connected to a server")
		return
	Logging.log_start("Joining lobby: %s" % id)
	Steam.joinLobby(id)

func leave_server() -> void:
	if get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		Logging.log_error("Error leaving server: You are not currently connected to a server")
		return
	Logging.log_start("Leaving server")
	close_connection()

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
		Logging.log_error("Error joining lobby: %s" % reason)
		return
	lobby_id = id
	Logging.log_info("Joined lobby: %s" % lobby_id)
	create_peer()
	if multiplayer.is_server():
		Logging.log_complete("Server created")
		connection_successful.emit()
		return
	Logging.log_start("Connecting to server")

func create_peer() -> void:
	peer = SteamMultiplayerPeer.new()
	var host_id: int = Steam.getLobbyOwner(lobby_id)
	if host_id == Global.steam_id:
		peer.create_host(0)
	else:
		peer.create_client(host_id, 0)
	multiplayer.set_multiplayer_peer(peer)

func _on_connection_status_changed(_handle: int, connection: Dictionary, _old_state: int) -> void:
	if connection.end_reason == Steam.NetworkingConnectionEnd.CONNECTION_END_MISC_TIMEOUT:
		Logging.log_error(connection.end_debug)
		close_connection()

func _on_connected_to_server() -> void:
	Logging.log_complete("Connected to server")
	connection_successful.emit()

func _on_connection_failed() -> void:
	Logging.log_error("Error connecting to server")
	close_connection()

func _on_server_disconnected() -> void:
	Logging.log_end("Server closed")
	close_connection()

func _on_game_closed() -> void:
	if get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
		close_connection()

func close_connection() -> void:
	peer.close()
	peer = OfflineMultiplayerPeer.new()
	multiplayer.set_multiplayer_peer(peer)
	Steam.leaveLobby(lobby_id)
	lobby_id = 0
	Logging.log_end("Connection closed")
	connection_closed.emit()
