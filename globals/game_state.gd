extends Node

enum TurnPhase { MOVE_MAZE, MOVE_PLAYER }

var turn_order: Array[Player]
var turn_index: int:
	set(new_index):
		turn_index = max(new_index, 0) % (turn_order.size()+1)
		if is_environments_turn():
			active_player = null
		else:
			active_player = turn_order.get(turn_index)
var active_player: Player
var turn_phase: TurnPhase

func reset() -> void:
	turn_order.clear()
	turn_index = 0
	turn_phase = TurnPhase.MOVE_MAZE

func serialised() -> Dictionary:
	var data: Dictionary = {}
	# Turn order
	var turn_order_serialised: Array[int]
	for player: Player in turn_order:
		turn_order_serialised.append(player.id)
	data.set("turn_order", turn_order_serialised)
	data.set("turn_index", turn_index)
	return data

func load_data(data: Dictionary) -> void:
	# Turn order
	var turn_order_serialised: Array[int] = data.get("turn_order")
	turn_order.clear()
	for id: int in turn_order_serialised:
		turn_order.append(Network.players.get(id))
	turn_index = data.get("turn_index")

# -----
# GAME
# -----

func initialise_game() -> void:
	turn_order = Network.players.values()
	turn_order.shuffle()

func start_game() -> void:
	turn_index = 0
	start_turn()

# -----
# TURN
# -----

func is_my_turn() -> bool:
	if not active_player:
		return false
	return active_player.id == Global.player.id

func is_environments_turn() -> bool:
	return turn_index == turn_order.size()

func next_turn() -> void:
	turn_index += 1
	start_turn()

func start_turn() -> void:
	if is_environments_turn():
		print("Process environment's turn")
	else:
		turn_phase = TurnPhase.MOVE_MAZE
