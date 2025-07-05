class_name Tile extends Node3D

## Size of a tile in meters
const SIZE = 12

## Defines the shape of a tile, i.e. which directions you can enter/exit it from
enum Shape {
	## North and East (3)
	CORNER = Board.Direction.NORTH + Board.Direction.EAST,
	## North and South (5)
	STRAIGHT = Board.Direction.NORTH + Board.Direction.SOUTH,
	## North, East and South (7)
	JUNCTION = Board.Direction.NORTH + Board.Direction.EAST + Board.Direction.SOUTH,
	## North, East, South and West (15)
	CROSS = Board.Direction.NORTH + Board.Direction.EAST + Board.Direction.SOUTH + Board.Direction.WEST
}

@export var type: TileType
@export var graphics_parent: Node3D

var shape: Shape = Shape.CORNER
var rotations: int:
	set(new_value):
		rotations = new_value % 4
var pos: Vector2i:
	set(new_pos):
		pos = new_pos
		position = Board.board_to_world_pos(pos)

func _ready() -> void:
	update_graphics()

# Instantiates the graphics corresponding to the tile's shape
func update_graphics() -> void:
	# Clear graphics parent
	for child: Node in graphics_parent.get_children():
		graphics_parent.remove_child(child)
		child.queue_free()
	# Instantiate graphics if shape exists
	if not type.shapes.has(shape):
		return
	var graphics: Node3D = type.shapes.get(shape).instantiate()
	graphics_parent.add_child(graphics)
	graphics_parent.rotation_degrees.y = -90 * rotations

func serialised() -> Dictionary:
	var data: Dictionary = {}
	data.set("type", type.id)
	data.set("shape", shape)
	data.set("rotations", rotations)
	data.set("x", pos.x)
	data.set("y", pos.y)
	return data

static func deserialised(data: Dictionary) -> Tile:
	var tile_type: TileType = Data.Tiles.get_type(data.get("type"))
	var tile: Tile = tile_type.scene.instantiate()
	tile.shape = data.get("shape")
	tile.rotations = data.get("rotations")
	tile.pos = Vector2i(data.get("x"), data.get("y"))
	return tile

func copy() -> Tile:
	var tile: Tile = type.scene.instantiate()
	tile.shape = shape
	tile.rotations = rotations
	tile.pos = pos
	return tile

func can_move(direction: Board.Direction) -> bool:
	# Perform a bitwise rotation left on the shape value for each tile rotation
	var shape_rotated: int = Utils.rotate_left(shape, rotations, 4)
	# Return whether the shape value contains the direction value
	return shape_rotated & direction
