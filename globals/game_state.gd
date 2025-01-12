extends Node

var player: Player
var players: Dictionary

signal players_changed
signal player_joined(player: Player)
signal player_left(player: Player)

func _ready() -> void:
	Steam.avatar_loaded.connect(_on_avatar_loaded)
	Network.connection_successful.connect(_on_connection_successful)
	Network.connection_closed.connect(_on_connection_closed)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	reset()

func reset() -> void:
	player = Player.new()
	player.steam_id = Global.steam_id
	player.name = Global.steam_username
	Steam.getPlayerAvatar(Steam.AVATAR_LARGE)
	players.clear()

func _on_avatar_loaded(_id: int, size: int, bytes: PackedByteArray) -> void:
	player.load_icon(size, bytes)

func get_players_sorted() -> Array:
	var sorted: Array = players.values()
	sorted.sort_custom(func(p1: Player, p2: Player) -> bool: return p1.index < p2.index)
	return sorted

func get_players_serialised() -> Array[Dictionary]:
	var data: Array[Dictionary] = []
	for _player: Player in players.values():
		data.append(_player.serialised())
	return data

func get_player(id: int) -> Player:
	return players[id]

func register_player(_player: Player) -> void:
	_player.index = players.size()
	players[_player.id] = _player
	Logging.log_info("Registered player: ID = %s, Name: %s" % [_player.id, _player.name])
	players_changed.emit()

func unregister_player(id: int) -> void:
	players.erase(id)
	Logging.log_info("Unregistered player: ID = %s" % id)
	players_changed.emit()

@rpc("authority", "call_remote", "reliable")
func update_player_data(data: Array[Dictionary]) -> void:
	players.clear()
	for player_data: Dictionary in data:
		var _player := Player.deserialised(player_data)
		if player.id == _player.id:
			player = _player
		players[_player.id] = _player
	players_changed.emit()

@rpc("any_peer", "call_remote", "reliable")
func player_connected(player_data: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var _player := Player.deserialised(player_data)
	register_player(_player)
	update_player_data.rpc(get_players_serialised())
	Logging.log_complete("%s joined" % _player.name)
	player_joined.emit(_player)

func _on_connection_successful() -> void:
	player.id = multiplayer.get_unique_id()
	if multiplayer.is_server():
		register_player(player)
	else:
		player_connected.rpc_id(1, player.serialised())

func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
	var _player: Player = get_player(id)
	unregister_player(id)
	update_player_data.rpc(get_players_serialised())
	Logging.log_end("%s left" % _player.name)
	player_left.emit(_player)

func _on_connection_closed() -> void:
	reset()
