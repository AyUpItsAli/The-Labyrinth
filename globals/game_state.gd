extends Node

enum TurnPhase { MOVE_MAZE, END }

var turn_order: Array[Player]
var turn_index: int:
	set(new_index):
		turn_index = max(new_index, 0) % (turn_order.size()+1)
		if turn_index == turn_order.size():
			# Environment's turn, therefore active player is null
			active_player = null
		else:
			active_player = turn_order.get(turn_index)
		# Pause turn if it's my turn
		set_paused(is_my_turn())
var active_player: Player
var turn_paused: bool
var turn_phase: TurnPhase

func _ready() -> void:
	Network.ack_resolved.connect(_on_ack_resolved)

func reset() -> void:
	turn_order.clear()
	turn_index = 0
	turn_phase = TurnPhase.MOVE_MAZE

func initialise() -> void:
	turn_order = Network.players.values()
	turn_order.shuffle()
	turn_index = 0
	turn_phase = TurnPhase.MOVE_MAZE

func serialised() -> Dictionary:
	var data: Dictionary = {}
	var turn_order_serialised: Array[int]
	for player: Player in turn_order:
		turn_order_serialised.append(player.id)
	data.set("turn_order", turn_order_serialised)
	data.set("turn_index", turn_index)
	data.set("turn_phase", turn_phase)
	return data

func load_data(data: Dictionary) -> void:
	var turn_order_serialised: Array[int] = data.get("turn_order")
	turn_order.clear()
	for id: int in turn_order_serialised:
		turn_order.append(Network.players.get(id))
	turn_index = data.get("turn_index")
	turn_phase = data.get("turn_phase")

# -----
# TURN
# -----

func is_my_turn() -> bool:
	return active_player and active_player.id == Global.player.id

func is_phase(phase: TurnPhase) -> bool:
	return not turn_paused and turn_phase == phase

func _on_ack_resolved(id: String) -> void:
	match id:
		"turn_updated": start_turn()
		"phase_updated": set_paused(false)

func start_turn() -> void:
	# Server-side only
	if not multiplayer.is_server():
		return
	if is_my_turn():
		set_paused(false)
	elif active_player:
		set_paused.rpc_id(active_player.id, false)
	else:
		print("Process environment's turn")
		next_turn.rpc()

@rpc("authority", "call_remote", "reliable")
func set_paused(paused: bool) -> void:
	turn_paused = paused

@rpc("any_peer", "call_local", "reliable")
func next_turn() -> void:
	turn_index += 1
	turn_phase = TurnPhase.MOVE_MAZE
	Network.send_ack("turn_updated", 1)

@rpc("any_peer", "call_local", "reliable")
func next_phase() -> void:
	if turn_phase == TurnPhase.END:
		return
	turn_phase = (turn_phase+1) as TurnPhase
	var sender: int = multiplayer.get_remote_sender_id()
	Network.send_ack("phase_updated", sender)

func _unhandled_input(event: InputEvent) -> void:
	if not GameState.is_my_turn():
		return
	if not GameState.is_phase(GameState.TurnPhase.END):
		return
	if event.is_action_pressed("select"):
		next_turn.rpc()
