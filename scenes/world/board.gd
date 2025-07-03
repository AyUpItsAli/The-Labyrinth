class_name Board extends Node3D

enum Direction { NORTH = 1, EAST = 2, SOUTH = 4, WEST = 8 }

@export_group("Settings")
@export_range(3, 21, 1, "suffix:tiles") var size: int = 7:
	set(new_size):
		size = new_size+1 if new_size % 2 == 0 else new_size
@export_group("Nodes")
@export var tile_container: Node3D
@export var camera: Camera

var tiles: Dictionary[Vector2i, Tile]
var free_tile: Tile

## Converts 2D board position to 3D world position local to the board
static func board_to_world_pos(pos: Vector2i) -> Vector3:
	return Vector3(pos.x * Tile.SIZE, 0, pos.y * Tile.SIZE)

## Converts 3D world position local to the board to 2D board position
static func world_to_board_pos(pos: Vector3) -> Vector2i:
	return Vector2i(round(pos.x / Tile.SIZE), round(pos.z / Tile.SIZE))

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

func add_tile(tile: Tile, pos: Vector2i) -> void:
	tile.pos = pos
	tile.name = "Tile (%s,%s)" % [pos.x, pos.y]
	tile_container.add_child(tile)
	tiles.set(pos, tile)

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
	free_tile.name = "Free Tile"
	# Camera limits
	camera.max_distance = ((size / 2.0) + 1) * Tile.SIZE

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
	var edge := int(size / 2.0) + 1
	return (x == edge and y < edge) or (y == edge and x < edge)

func update_free_tile() -> void:
	if not free_tile:
		Utils.log_error("Free Tile is null!")
		return
	var target_pos: Vector2i = camera.get_mouse_board_pos()
	if valid_edge_pos(target_pos):
		if target_pos != free_tile.pos:
			free_tile.pos = target_pos
		if not free_tile.is_inside_tree():
			tile_container.add_child(free_tile)
	elif free_tile.is_inside_tree():
		tile_container.remove_child(free_tile)

func _unhandled_input(event: InputEvent) -> void:
	if not GameState.is_my_turn():
		return
	if not GameState.turn_phase == GameState.TurnPhase.MOVE_MAZE:
		return
	if event is InputEventMouseMotion:
		update_free_tile()
