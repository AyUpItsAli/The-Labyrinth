class_name Tile extends Node3D

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

var shape: Shape = Shape.CORNER

func _ready() -> void:
	instantiate_graphics()

# Instantiates the graphics corresponding to the tile's shape
func instantiate_graphics() -> void:
	# Clear graphics parent
	for child: Node in graphics_parent.get_children():
		child.queue_free()
	# Instantiate graphics if shape exists
	if not shapes.has(shape):
		return
	var graphics: Node3D = shapes.get(shape).instantiate()
	graphics_parent.add_child(graphics)

# Returns the number of times this tile has been rotated
func get_rotations() -> int:
	# Calculate the number of 90 degree rotations on the graphics parent
	return roundi(fposmod(graphics_parent.rotation_degrees.y, 360) / 90)

func can_move(direction: Board.Direction) -> bool:
	# Get the number of rotations for this tile
	var rotations: int = get_rotations()
	# Perform a bitwise rotation left on the shape value for each rotation
	var shape_rotated: int = Utils.rotate_left(shape, rotations, Board.Direction.size())
	# Return whether the shape value contains the direction value
	return shape_rotated & direction
