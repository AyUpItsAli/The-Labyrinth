extends Node

var player: Player
var players: Dictionary
var chat: Array[Dictionary]

signal players_updated
signal chat_updated

func _ready() -> void:
	Steam.avatar_loaded.connect(_on_avatar_loaded)
	Network.player_connected.connect(_on_player_connected)
	Network.player_disconnected.connect(_on_player_disconnected)
	reset()

func reset() -> void:
	player = Player.new()
	player.steam_id = Global.steam_id
	player.name = Global.steam_username
	Steam.getPlayerAvatar(Steam.AVATAR_LARGE)
	players.clear()

func _on_avatar_loaded(_id: int, size: int, bytes: PackedByteArray) -> void:
	player.load_icon(size, bytes)

func serialised() -> Dictionary:
	var data: Dictionary = {}
	data["players"] = get_players_serialised()
	data["chat"] = chat
	return data

func update(data: Dictionary) -> void:
	update_players(data["players"])
	chat = data["chat"]
	chat_updated.emit()

# ---------
# PLAYERS
# ---------

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

func get_player(id: int) -> Player:
	return players[id]

func get_players_sorted() -> Array:
	var sorted: Array = players.values()
	sorted.sort_custom(func(plr1: Player, plr2: Player) -> bool: return plr1.index < plr2.index)
	return sorted

func register_player(new_player: Player) -> void:
	# Server-side setup for new players
	if multiplayer.is_server():
		new_player.index = players.size() # Set register order index
	# Register player
	players[new_player.id] = new_player
	Logging.log_info("Registered player: ID = %s, Name: %s" % [new_player.id, new_player.name])
	players_updated.emit()
	# Register new player for clients
	if multiplayer.is_server():
		register_player_serialised.rpc(new_player.serialised())

@rpc("authority", "call_remote", "reliable")
func register_player_serialised(player_data: Dictionary) -> void:
	register_player(Player.deserialised(player_data))

func unregister_player(old_player: Player) -> void:
	# Server-side only
	if not multiplayer.is_server():
		return
	# Remove player
	players.erase(old_player.id)
	# Ensure remaining players have the correct index
	var index: int = 0
	for plr: Player in get_players_sorted():
		plr.index = index
		index += 1
	Logging.log_info("Unregistered player: ID = %s, Name: %s" % [old_player.id, old_player.name])
	players_updated.emit()
	# Update clients
	update_players.rpc(get_players_serialised())

# ------
# CHAT
# ------

func send_chat_message(message: String) -> void:
	message = message.strip_edges()
	if message.is_empty():
		return
	receive_player_message.rpc_id(1, message)

func send_system_message(message: String) -> void:
	if not multiplayer.is_server():
		return

@rpc("any_peer", "call_local", "reliable")
func receive_player_message(message: String) -> void:
	if not multiplayer.is_server():
		return
	var sent_by: int = multiplayer.get_remote_sender_id()
	var sender: Player = get_player(sent_by)
	var content: String = "[color=white]%s:[/color] %s\n" % [sender.name, message]

func _on_player_connected(new_player: Player) -> void:
	if not multiplayer.is_server():
		return
	var content: String = "[color=green]%s joined[/color]\n" % new_player.name

func _on_player_disconnected(old_player: Player) -> void:
	if not multiplayer.is_server():
		return
	var content: String = "[color=red]%s left[/color]\n" % old_player.name
