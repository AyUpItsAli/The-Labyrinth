class_name InvitePopup extends DialogPopup

@export var player_list: ItemList

var players: Array

func _ready() -> void:
	super._ready()
	Steam.avatar_loaded.connect(_on_avatar_loaded)
	player_list.clear()
	for i in Steam.getFriendCount():
		var friend_id: int = Steam.getFriendByIndex(i, Steam.FRIEND_FLAG_IMMEDIATE)
		var game_info: Dictionary = Steam.getFriendGamePlayed(friend_id)
		if game_info.is_empty():
			continue
		if game_info["id"] != Global.APP_ID:
			continue
		if game_info["lobby"] != 0:
			continue
		Steam.getPlayerAvatar(Steam.AVATAR_LARGE, friend_id)

func _on_avatar_loaded(id: int, icon_size: int, bytes: PackedByteArray) -> void:
	var player_name: String = Steam.getFriendPersonaName(id)
	var player_icon: ImageTexture = Player.load_icon(icon_size, bytes)
	var i: int = player_list.add_item(player_name, player_icon, false)
	player_list.set_item_tooltip_enabled(i, false)
	players.append(id)

func _on_player_list_item_clicked(i: int, _pos: Vector2, button_index: int) -> void:
	if button_index != MOUSE_BUTTON_LEFT:
		return
	if Steam.inviteUserToLobby(Network.lobby_id, players[i]):
		player_list.set_item_disabled(i, true)
		player_list.set_item_text(i, "%s | Invite Sent" % player_list.get_item_text(i))

func _on_close_btn_pressed() -> void:
	close()
