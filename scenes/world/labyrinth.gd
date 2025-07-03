extends Node3D

@export var board: Board
@export var camera: Camera

func _ready() -> void:
	Network.ack_resolved.connect(_on_ack_resolved)
	# Server initialises the game
	if multiplayer.is_server():
		await initialise_game()
	# Display waiting message
	Utils.log_start("Waiting for players")
	await Overlay.display_loading_message("Waiting for players")
	# Wait for all players to load the scene
	Network.register_server_ack("labyrinth_loaded")

func initialise_game() -> void:
	Utils.log_start("Initialising game")
	await Overlay.display_loading_message("Initialising the game")
	GameState.initialise_game()
	await Overlay.display_loading_message("Generating the board")
	board.generate()
	Utils.log_success("Initialisation complete")

func _on_ack_resolved(id: String) -> void:
	match id:
		"labyrinth_loaded": sync_clients()
		"game_initialised": start_game.rpc()

func sync_clients() -> void:
	Utils.log_start("Synchronising clients")
	# Collect game data
	var data: Dictionary = {}
	data.set("game_state", GameState.serialised())
	data.set("board", board.serialised())
	data.set("camera_max_distance", camera.max_distance)
	# Synchronise game data with clients
	load_data.rpc(data)
	# Wait for all players to initialise the game
	Network.register_server_ack("game_initialised")

@rpc("authority", "call_remote", "reliable")
func load_data(data: Dictionary) -> void:
	Utils.log_start("Loading game data")
	# Initialise game with the given data
	GameState.load_data(data.get("game_state"))
	board.load_data(data.get("board"))
	camera.max_distance = data.get("camera_max_distance")
	Utils.log_success("Game loaded")
	# Tell the server we have initialised the game
	Network.register_server_ack("game_initialised")

@rpc("authority", "call_local", "reliable")
func start_game() -> void:
	Utils.log_start("Starting game")
	GameState.start_game()
	Overlay.finish_loading()
