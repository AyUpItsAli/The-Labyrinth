extends Node

var player: Player
var players: Dictionary

signal players_updated

func _ready() -> void:
	Steam.avatar_loaded.connect(_on_avatar_loaded)
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
	sorted.sort_custom(func(plr1: Player, plr2: Player) -> bool: return plr1.index < plr2.index)
	return sorted

func get_players_serialised() -> Array[Dictionary]:
	var data: Array[Dictionary] = []
	for plr: Player in players.values():
		data.append(plr.serialised())
	return data

func get_player(id: int) -> Player:
	return players[id]

func register_player(new_player: Player) -> void:
	new_player.index = players.size()
	players[new_player.id] = new_player
	Logging.log_info("Registered player: ID = %s, Name: %s" % [new_player.id, new_player.name])
	update_player_data.rpc(get_players_serialised())
	players_updated.emit()

func unregister_player(old_player: Player) -> void:
	players.erase(old_player.id)
	# TODO: Update player indexes
	Logging.log_info("Unregistered player: ID = %s, Name: %s" % [old_player.id, old_player.name])
	update_player_data.rpc(get_players_serialised())
	players_updated.emit()

@rpc("authority", "call_remote", "reliable")
func update_player_data(data: Array[Dictionary]) -> void:
	players.clear()
	for player_data: Dictionary in data:
		var new_player := Player.deserialised(player_data)
		if player.id == new_player.id:
			player = new_player
		players[new_player.id] = new_player
	players_updated.emit()
