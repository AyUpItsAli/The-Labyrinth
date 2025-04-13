class_name Player extends Object

const MAX_ICON_SIZE = 128

var id: int # Peer id (host id = 1)
var index: int # Register order (host index = 0)
var steam_id: int
var name: String
var icon: ImageTexture

func is_host() -> bool:
	return id == 1

func serialised() -> Dictionary:
	var data: Dictionary
	data.set("id", id)
	data.set("index", index)
	data.set("steam_id", steam_id)
	data.set("name", name)
	var image: Image = icon.get_image()
	data.set("icon_size", image.get_size().x)
	data.set("icon_bytes", image.get_data())
	return data

static func deserialised(data: Dictionary) -> Player:
	var player := Player.new()
	player.id = data.get("id")
	player.index = data.get("index")
	player.steam_id = data.get("steam_id")
	player.name = data.get("name")
	player.icon = Player.load_icon(data.get("icon_size"), data.get("icon_bytes"))
	return player

static func load_icon(size: int, bytes: PackedByteArray) -> ImageTexture:
	var image := Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, bytes)
	if size > MAX_ICON_SIZE:
		image.resize(MAX_ICON_SIZE, MAX_ICON_SIZE, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(image)
