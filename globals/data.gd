extends Node

const TILE_TYPES: ResourceGroup = preload("res://data/world/tile_types.tres")

func _ready() -> void:
	Tiles.load_types()

class Tiles:
	static var types: Dictionary[String, TileType]
	
	static func load_types() -> void:
		for path in TILE_TYPES.paths:
			var type: TileType = load(path)
			type.scene = load(type.scene_uid)
			types.set(type.id, type)
	
	static func get_types() -> Array[TileType]:
		return types.values()
	
	static func get_type(id: String) -> TileType:
		return types.get(id)
