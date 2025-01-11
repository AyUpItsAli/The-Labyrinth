extends Node

var player: Player
var players: Dictionary

signal players_changed

func _ready() -> void:
	Steam.avatar_loaded.connect(_on_avatar_loaded)
	Network.connection_successful.connect(_on_connection_successful)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	Network.connection_closed.connect(_on_connection_closed)
	reset()

func reset() -> void:
	player = Player.new()
	player.steam_id = Global.steam_id
	player.name = Global.steam_username
	Steam.getPlayerAvatar(Steam.AVATAR_LARGE)
	players.clear()

func _on_avatar_loaded(_id: int, size: int, bytes: PackedByteArray) -> void:
	player.load_icon(size, bytes)

func get_players() -> Array:
	var sorted: Array = players.values()
	sorted.sort_custom(
		func(p1: Player, p2: Player) -> bool:
			return players.find_key(p1) < players.find_key(p2)
	)
	return sorted

func get_player(id: int) -> Player:
	return players[id]

func register_player(new_player: Player) -> void:
	players[new_player.id] = new_player
	Logging.log_info("Registered player: ID = %s, Name: %s" % [new_player.id, new_player.name])
	players_changed.emit()

func unregister_player(id: int) -> void:
	players.erase(id)
	Logging.log_info("Unregistered player: ID = %s" % id)
	players_changed.emit()

@rpc("any_peer", "call_remote", "reliable")
func register_player_data(data: Dictionary) -> void:
	register_player(Player.deserialised(data))

func _on_connection_successful() -> void:
	player.id = Network.peer.get_unique_id()
	register_player(player)

func _on_peer_connected(id: int) -> void:
	register_player_data.rpc_id(id, player.serialised())

func _on_peer_disconnected(id: int) -> void:
	unregister_player(id)

func _on_connection_closed() -> void:
	reset()
