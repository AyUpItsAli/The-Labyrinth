class_name Board extends Node3D

enum Direction { NORTH = 1, EAST = 2, SOUTH = 4, WEST = 8 }

@export_group("Settings")
@export_range(3, 21, 1, "suffix:tiles") var size: int = 7:
	set(new_size):
		size = new_size+1 if new_size % 2 == 0 else new_size
@export_group("Nodes")
@export var tile_container: Node3D
@export var camera: Camera

var edge: int
var tiles: Dictionary[Vector2i, Tile]
var free_tile: Tile:
	set(new_tile):
		free_tile = new_tile
		free_tile.name = "Free Tile"

## Converts 2D board position to 3D world position local to the board
static func board_to_world_pos(pos: Vector2i) -> Vector3:
	return Vector3(pos.x * Tile.SIZE, 0, pos.y * Tile.SIZE)

## Converts 3D world position local to the board to 2D board position
static func world_to_board_pos(pos: Vector3) -> Vector2i:
	return Vector2i(round(pos.x / Tile.SIZE), round(pos.z / Tile.SIZE))

## Returns the Vector2i offset for the given Direction
static func get_offset(direction: Direction) -> Vector2i:
	match direction:
		Direction.NORTH: return Vector2i.UP
		Direction.SOUTH: return Vector2i.DOWN
		Direction.EAST: return Vector2i.RIGHT
		_: return Vector2i.LEFT

func _ready() -> void:
	Network.ack_resolved.connect(_on_ack_resolved)
	edge = int(size / 2.0) + 1
	camera.max_distance = ((size / 2.0) + 1) * Tile.SIZE

# ------
# TILES
# ------

func clear() -> void:
	for tile: Tile in tile_container.get_children():
		tile_container.remove_child(tile)
		tile.queue_free()
	tiles.clear()

func generate_tile(tile_type: String = "") -> Tile:
	var type: TileType
	if tile_type.is_empty():
		type = Data.Tiles.get_types().pick_random()
	else:
		type = Data.Tiles.get_type(tile_type)
	var tile: Tile = type.scene.instantiate()
	tile.shape = type.shapes.keys().pick_random()
	tile.rotations = randi_range(0, 3)
	return tile

func update_tile(tile: Tile, pos: Vector2i) -> void:
	if tiles.values().has(tile):
		tiles.erase(tile.pos)
	tile.pos = pos
	tile.name = "Tile (%s,%s)" % [pos.x, pos.y]
	tiles.set(pos, tile)

# TODO: Only one arg
func add_tile(tile: Tile, pos: Vector2i) -> void:
	update_tile(tile, pos)
	tile_container.add_child(tile)

func remove_tile(tile: Tile) -> void:
	tiles.erase(tile.pos)
	tile_container.remove_child(tile)
	tile.queue_free()

func generate() -> void:
	# TODO: Generate in another thread
	# Tiles
	clear()
	var end := int(size / 2.0)
	var start: int = -end
	for x in range(start, end + 1):
		for y in range(start, end + 1):
			var tile: Tile = generate_tile()
			add_tile(tile, Vector2i(x, y))
	# Free Tile
	free_tile = generate_tile("basic")

# --------------
# SERIALISATION
# --------------

func serialised() -> Dictionary:
	var data: Dictionary = {}
	# Tiles
	var tiles_data: Dictionary = {}
	for pos: Vector2i in tiles:
		var tile: Tile = tiles.get(pos)
		tiles_data.set(pos, tile.serialised())
	data.set("tiles", tiles_data)
	# Free Tile
	data.set("free_tile", free_tile.serialised())
	return data

func load_data(data: Dictionary) -> void:
	# Tiles
	clear()
	var tiles_data: Dictionary = data.get("tiles")
	for pos: Vector2i in tiles_data:
		var tile := Tile.deserialised(tiles_data.get(pos))
		add_tile(tile, pos)
	# Free Tile
	free_tile = Tile.deserialised(data.get("free_tile"))

# ----------
# FREE TILE
# ----------

func valid_edge_pos(pos: Vector2i) -> bool:
	var x: int = abs(pos.x)
	var y: int = abs(pos.y)
	return (x == edge and y < edge) or (y == edge and x < edge)

func update_free_tile() -> void:
	var target_pos: Vector2i = camera.get_mouse_board_pos()
	if valid_edge_pos(target_pos):
		if free_tile.pos != target_pos:
			free_tile.pos = target_pos
		if not free_tile.is_inside_tree():
			tile_container.add_child(free_tile)
	elif free_tile.is_inside_tree():
		tile_container.remove_child(free_tile)

func rotate_free_tile() -> void:
	if not free_tile.is_inside_tree():
		return
	free_tile.rotations += 1
	free_tile.update_graphics()

func _unhandled_input(event: InputEvent) -> void:
	if not GameState.is_my_turn():
		return
	if not GameState.turn_phase == GameState.TurnPhase.MOVE_MAZE:
		return
	if event is InputEventMouseMotion:
		update_free_tile()
	elif event.is_action_pressed("rotate_tile"):
		rotate_free_tile()
	elif event.is_action_pressed("select"):
		move_maze()

func move_maze() -> void:
	if not free_tile.is_inside_tree():
		return
	# Set turn phase to idle
	GameState.turn_phase = GameState.TurnPhase.IDLE
	# Remove the free tile from view
	tile_container.remove_child(free_tile)
	# Move tiles
	move_tiles.rpc(free_tile.serialised())

@rpc("any_peer", "call_local", "reliable")
func move_tiles(data: Dictionary) -> void:
	# Get the sender, for later
	var sender: int = multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = Global.player.id
	# Deserialise the new tile and add it to the board
	var new_tile := Tile.deserialised(data)
	add_tile(new_tile, new_tile.pos)
	# Determine move direction
	var direction: Direction = Direction.NORTH
	if new_tile.pos.y == -edge:
		direction = Direction.SOUTH
	elif new_tile.pos.x == -edge:
		direction = Direction.EAST
	elif new_tile.pos.x == edge:
		direction = Direction.WEST
	# Get the target tiles to move, based on the move direction
	var target_tiles: Array[Tile]
	if direction == Direction.NORTH or direction == Direction.SOUTH:
		# Target tiles are on the same column as the new tile (same x value)
		target_tiles = tiles.values().filter(
			func(tile: Tile) -> bool:
				return tile.pos.x == new_tile.pos.x
		)
		# Sort target tiles by their row number (their y position)
		target_tiles.sort_custom(
			func(a: Tile, b: Tile) -> bool:
				return a.pos.y < b.pos.y
		)
	else:
		# Target tiles are on the same row as the new tile (same y value)
		target_tiles = tiles.values().filter(
			func(tile: Tile) -> bool:
				return tile.pos.y == new_tile.pos.y
		)
		# Sort target tiles by their column number (their x position)
		target_tiles.sort_custom(
			func(a: Tile, b: Tile) -> bool:
				return a.pos.x < b.pos.x
		)
	# Reverse the order of the target tiles for SOUTH and EAST directions
	if direction == Direction.SOUTH or direction == Direction.EAST:
		target_tiles.reverse()
	# Move the target tiles
	var tween: Tween = create_tween().set_parallel(true)
	for tile: Tile in target_tiles:
		var new_pos: Vector2i = tile.pos + get_offset(direction)
		tween.tween_property(tile, "position", board_to_world_pos(new_pos), 2)
	await tween.finished
	# Remove first tile (the tile that was "knocked off" the board)
	var removed: Tile = target_tiles.pop_front()
	remove_tile(removed)
	# Update the remaining tiles in order
	for tile: Tile in target_tiles:
		var new_pos: Vector2i = world_to_board_pos(tile.position)
		update_tile(tile, new_pos)
	# Set the free tile to a copy of the removed tile
	free_tile = removed.copy()
	# Send acknowledgement back to the sender
	Network.send_ack(sender, "tiles_moved")

func _on_ack_resolved(id: String) -> void:
	match id:
		"tiles_moved": post_move_tiles()

func post_move_tiles() -> void:
	# TODO: Move to next phase...
	GameState.turn_phase = GameState.TurnPhase.MOVE_MAZE
