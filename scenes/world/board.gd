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

## Converts 2D board position to 3D world position local to the board
func board_to_world_pos(pos: Vector2i) -> Vector3:
	return Vector3(pos.x * Tile.SIZE, 0, pos.y * Tile.SIZE)

## Converts 3D world position local to the board to 2D board position
func world_to_board_pos(pos: Vector3) -> Vector2i:
	return Vector2i(round(pos.x / Tile.SIZE), round(pos.z / Tile.SIZE))

func clear() -> void:
	for tile: Tile in tile_container.get_children():
		tile_container.remove_child(tile)
		tile.queue_free()
	tiles.clear()

func generate_tile() -> Tile:
	var type: TileType = Data.Tiles.get_types().pick_random()
	var tile: Tile = type.scene.instantiate()
	tile.shape = type.shapes.keys().pick_random()
	tile.rotations = randi_range(0, 3)
	return tile

func add_tile(tile: Tile, pos: Vector2i) -> void:
	tile.pos = pos
	tile.position = board_to_world_pos(pos)
	tile_container.add_child(tile)
	tiles.set(pos, tile)

func generate() -> void:
	camera.max_distance = ((size / 2.0) + 1) * Tile.SIZE
	# TODO: Generate in another thread
	clear()
	var end := int(size / 2.0)
	var start: int = -end
	for x in range(start, end + 1):
		for y in range(start, end + 1):
			var tile: Tile = generate_tile()
			add_tile(tile, Vector2i(x, y))

func serialised() -> Dictionary:
	var data: Dictionary = {}
	var tiles_data: Dictionary = {}
	for pos: Vector2i in tiles:
		var tile: Tile = tiles.get(pos)
		tiles_data.set(pos, tile.serialised())
	data.set("tiles", tiles_data)
	return data

func load_data(data: Dictionary) -> void:
	clear()
	var tiles_data: Dictionary = data.get("tiles")
	for pos: Vector2i in tiles_data:
		var tile := Tile.deserialised(tiles_data.get(pos))
		add_tile(tile, pos)

func get_mouse_world_pos() -> Vector3:
	if not camera:
		return Vector3.ZERO
	var viewport_pos: Vector2 = get_viewport().get_mouse_position()
	var from: Vector3 = camera.camera.project_ray_origin(viewport_pos)
	var to: Vector3 = camera.camera.project_position(viewport_pos, 1000)
	var result: Variant = Plane.PLANE_XZ.intersects_segment(from, to)
	return Vector3.ZERO if result == null else result

func get_mouse_board_pos() -> Vector2i:
	return world_to_board_pos(get_mouse_world_pos())

var piece_pos: Vector2i
var piece: Tile

func valid_pos(pos: Vector2i) -> bool:
	var x: int = abs(pos.x)
	var y: int = abs(pos.y)
	var edge := int(size / 2.0) + 1
	return (x == edge and y < edge) or (y == edge and x < edge)

func display_piece() -> void:
	var pos: Vector2i = get_mouse_board_pos()
	if piece:
		if pos == piece.pos:
			return
		tile_container.remove_child(piece)
		piece.queue_free()
	if not GameState.is_my_turn():
		return
	if not valid_pos(pos):
		return
	var type: TileType = Data.Tiles.get_type("basic")
	piece = type.scene.instantiate()
	piece.shape = Tile.Shape.CORNER
	piece.rotations = 0
	piece.position = board_to_world_pos(pos)
	tile_container.add_child(piece)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		display_piece()
