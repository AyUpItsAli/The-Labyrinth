extends Node3D

@export var board: Board

func _ready() -> void:
	Network.ack_confirmed.connect(_on_ack_confirmed)
	# Server initialises the game
	if multiplayer.is_server():
		await initialise_game()
	# Display waiting message
	Utils.log_start("Waiting for players")
	Overlay.display_loading_message("Waiting for players")
	# Server waits for clients to load the game
	# Clients send their acknowledgement to the server and wait for a response
	if multiplayer.is_server():
		Network.query_ack("game_loaded")
	else:
		Network.register_server_ack("game_loaded")

func initialise_game() -> void:
	Utils.log_start("Initialising game")
	await Overlay.display_loading_message("Generating the board")
	board.generate()
	Utils.log_success("Initialisation complete")

func _on_ack_confirmed(id: String) -> void:
	match id:
		"game_loaded": sync_clients()
		"game_initialised": start_game()

func sync_clients() -> void:
	Utils.log_start("Synchronising clients")
	# Collect game data
	var data: Dictionary = {}
	data.set("board", board.serialised())
	# Synchronise game data with clients
	load_data.rpc(data)
	# Wait for clients to initialise the game
	Network.query_ack("game_initialised")

@rpc("authority", "call_remote", "reliable")
func load_data(data: Dictionary) -> void:
	Utils.log_start("Loading game data")
	board.load_data(data.get("board"))
	Utils.log_success("Game loaded")
	Network.register_server_ack("game_initialised")
	# TODO: Server tells clients when to start game
	start_game()

func start_game() -> void:
	Utils.log_start("Starting game")
	Overlay.finish_loading()
