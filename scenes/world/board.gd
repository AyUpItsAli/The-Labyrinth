class_name Board extends Node3D

enum Direction { NORTH = 1, EAST = 2, SOUTH = 4, WEST = 8 }

@export var tile_container: Node3D
@export_group("Settings")
@export_range(3, 20) var size: int = 7

func _ready() -> void:
	generate_board()

func clear_board() -> void:
	for tile: Tile in tile_container.get_children():
		tile_container.remove_child(tile)
		tile.queue_free()

## Converts 2D board position into 3D world position local to the board
func board_to_world_pos(board_pos: Vector2i) -> Vector3:
	return Vector3(board_pos.x * Tile.SIZE, 0, board_pos.y * Tile.SIZE)

func place_tile(type: TileType, board_pos: Vector2i) -> void:
	var tile: Tile = type.scene.instantiate()
	tile.name = "Tile (%s,%s)" % [board_pos.x, board_pos.y]
	tile.shape = tile.shapes.keys().pick_random()
	tile.rotations = randi_range(0, Tile.MAX_ROTATIONS)
	tile.position = board_to_world_pos(board_pos)
	tile_container.add_child(tile)

func generate_board() -> void:
	clear_board()
	var end := int(size / 2.0)
	var start: int = -end
	for x in range(start, end + 1):
		for y in range(start, end + 1):
			var type: TileType = Data.Tiles.get_types().pick_random()
			place_tile(type, Vector2i(x, y))
