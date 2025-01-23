class_name Player extends Object

const MAX_ICON_SIZE = 128

var id: int # Peer id (host id = 1)
var index: int # Register order (host index = 0)
var steam_id: int
var name: String
var icon: ImageTexture

func is_host() -> bool:
	return id == 1

func load_icon(size: int, bytes: PackedByteArray) -> void:
	var image := Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, bytes)
	if size > MAX_ICON_SIZE:
		image.resize(MAX_ICON_SIZE, MAX_ICON_SIZE, Image.INTERPOLATE_LANCZOS)
	icon = ImageTexture.create_from_image(image)

func serialised() -> Dictionary:
	var data: Dictionary
	data["id"] = id
	data["index"] = index
	data["steam_id"] = steam_id
	data["name"] = name
	data["icon_size"] = icon.get_image().get_size().x
	data["icon_bytes"] = icon.get_image().get_data()
	return data

static func deserialised(data: Dictionary) -> Player:
	var player := Player.new()
	player.id = data["id"]
	player.index = data["index"]
	player.steam_id = data["steam_id"]
	player.name = data["name"]
	player.load_icon(data["icon_size"], data["icon_bytes"])
	return player
