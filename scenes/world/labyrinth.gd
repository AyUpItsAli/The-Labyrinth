extends Node3D

@export var hud: HUD
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
	Network.send_ack("labyrinth_loaded", 1)

func initialise_game() -> void:
	Utils.log_start("Initialising game")
	await Overlay.display_loading_message("Initialising the game")
	GameState.initialise()
	await Overlay.display_loading_message("Generating the board")
	board.generate()
	hud.update()
	Utils.log_success("Initialisation complete")

func _on_ack_resolved(id: String) -> void:
	match id:
		"labyrinth_loaded": sync_clients()

## Called by the server when all players have loaded the scene
func sync_clients() -> void:
	Utils.log_start("Synchronising clients")
	# Synchronise game data with clients
	var data: Dictionary = {}
	data.set("game_state", GameState.serialised())
	data.set("board", board.serialised())
	load_data.rpc(data)
	# Finish loading and send ack to server
	await Overlay.finish_loading()
	Network.send_ack("turn_updated", 1)

@rpc("authority", "call_remote", "reliable")
func load_data(data: Dictionary) -> void:
	Utils.log_start("Loading game data")
	# Initialise game with the given data
	GameState.load_data(data.get("game_state"))
	board.load_data(data.get("board"))
	hud.update()
	Utils.log_success("Game loaded")
	# Finish loading and send ack to server
	await Overlay.finish_loading()
	Network.send_ack("turn_updated", 1)
