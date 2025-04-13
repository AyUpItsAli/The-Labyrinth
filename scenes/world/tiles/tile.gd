class_name Tile extends Node3D

## Size of a tile in meters
const SIZE = 12
## Maximum number of times a time can be rotated
const MAX_ROTATIONS = 3

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

@export_group("Graphics")
@export var graphics_parent: Node3D
## Mapping of tile shapes to tile graphics
@export var shapes: Dictionary[Tile.Shape, PackedScene]

var type: TileType
var shape: Shape = Shape.CORNER
var rotations: int:
	set(new_value):
		rotations = min(new_value, MAX_ROTATIONS)
## Board position
var pos: Vector2i:
	set(new_pos):
		pos = new_pos
		name = "Tile (%s,%s)" % [pos.x, pos.y]

func _ready() -> void:
	instantiate_graphics()

# Instantiates the graphics corresponding to the tile's shape
func instantiate_graphics() -> void:
	# Clear graphics parent
	for child: Node in graphics_parent.get_children():
		graphics_parent.remove_child(child)
		child.queue_free()
	# Instantiate graphics if shape exists
	if not shapes.has(shape):
		return
	var graphics: Node3D = shapes.get(shape).instantiate()
	graphics_parent.add_child(graphics)
	graphics_parent.rotation_degrees.y = 90 * rotations

func can_move(direction: Board.Direction) -> bool:
	# Perform a bitwise rotation left on the shape value for each tile rotation
	var shape_rotated: int = Utils.rotate_left(shape, rotations, Board.Direction.size())
	# Return whether the shape value contains the direction value
	return shape_rotated & direction

func serialised() -> Dictionary:
	var data: Dictionary = {}
	data.set("type", type.id)
	data.set("shape", shape)
	data.set("rotations", rotations)
	return data

static func deserialised(data: Dictionary) -> Tile:
	var tile_type: TileType = Data.Tiles.get_type(data.get("type"))
	var tile: Tile = tile_type.scene.instantiate()
	tile.type = tile_type
	tile.shape = data.get("shape")
	tile.rotations = data.get("rotations")
	return tile
