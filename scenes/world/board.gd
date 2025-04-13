class_name Board extends Node3D

enum Direction { NORTH = 1, EAST = 2, SOUTH = 4, WEST = 8 }

@export var tile_container: Node3D
@export_group("Settings")
@export_range(3, 20, 1, "suffix:tiles") var size: int = 7

var tiles: Dictionary[Vector2i, Tile]

## Converts 2D board position into 3D world position local to the board
func board_to_world_pos(pos: Vector2i) -> Vector3:
	return Vector3(pos.x * Tile.SIZE, 0, pos.y * Tile.SIZE)

func clear() -> void:
	for tile: Tile in tile_container.get_children():
		tile_container.remove_child(tile)
		tile.queue_free()
	tiles.clear()

func generate_tile() -> Tile:
	var type: TileType = Data.Tiles.get_types().pick_random()
	var tile: Tile = type.scene.instantiate()
	tile.type = type
	tile.shape = tile.shapes.keys().pick_random()
	tile.rotations = randi_range(0, Tile.MAX_ROTATIONS)
	return tile

func add_tile(tile: Tile, pos: Vector2i) -> void:
	tile.pos = pos
	tile.position = board_to_world_pos(pos)
	tile_container.add_child(tile)
	tiles.set(pos, tile)

func generate() -> void:
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

@rpc("authority", "call_remote", "reliable")
func load_data(data: Dictionary) -> void:
	clear()
	var tiles_data: Dictionary = data.get("tiles")
	for pos: Vector2i in tiles_data:
		var tile := Tile.deserialised(tiles_data.get(pos))
		add_tile(tile, pos)
