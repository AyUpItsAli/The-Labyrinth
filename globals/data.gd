extends Node

const TILE_TYPES: ResourceGroup = preload("res://data/world/tile_types.tres")

func _ready() -> void:
	Tiles.load_types()

class Tiles:
	static var _types: Dictionary[String, TileType]
	
	static func load_types() -> void:
		for path in TILE_TYPES.paths:
			var type: TileType = load(path)
			_types[type.id] = type
	
	static func get_types() -> Array[TileType]:
		return _types.values()
	
	static func get_type(id: String) -> TileType:
		return _types.get(id)
