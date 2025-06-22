class_name TileType extends Resource

@export var id: String
@export var scene_uid: String
## Mapping of tile shapes to tile graphics
@export var shapes: Dictionary[Tile.Shape, PackedScene]

var scene: PackedScene
