class_name Player extends Object

const MAX_ICON_SIZE = 128

# Steam
var steam_id: int
var steam_name: String
var icon: ImageTexture

# Game
var display_name: String
var id: int # Player/Peer id (host id = 1)
var index: int # Register order (host index = 0)

func load_icon() -> void:
	icon = await get_icon(steam_id)

func is_host() -> bool:
	return id == 1

func serialised() -> Dictionary:
	var data: Dictionary
	data.set("steam_id", steam_id)
	data.set("steam_name", steam_name)
	var image: Image = icon.get_image()
	data.set("icon_size", image.get_size().x)
	data.set("icon_bytes", image.get_data())
	data.set("display_name", display_name)
	data.set("id", id)
	data.set("index", index)
	return data

static func deserialised(data: Dictionary) -> Player:
	var player := Player.new()
	player.steam_id = data.get("steam_id")
	player.steam_name = data.get("steam_name")
	player.icon = create_icon(data.get("icon_size"), data.get("icon_bytes"))
	player.display_name = data.get("display_name")
	player.id = data.get("id")
	player.index = data.get("index")
	return player

## Creates a player icon, given the size and bytes
static func create_icon(size: int, bytes: PackedByteArray) -> ImageTexture:
	var image := Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, bytes)
	if size > MAX_ICON_SIZE:
		image.resize(MAX_ICON_SIZE, MAX_ICON_SIZE, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(image)

## Requests the given player's steam icon
static func get_icon(player_id: int) -> ImageTexture:
	Steam.getPlayerAvatar(Steam.AVATAR_LARGE, player_id)
	var result: Array = await Steam.avatar_loaded
	return create_icon(result[1], result[2])
