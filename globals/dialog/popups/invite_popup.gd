class_name InvitePopup extends DialogPopup

@export var friends_list: ItemList

var friends: Array

func _ready() -> void:
	super._ready()
	Steam.avatar_loaded.connect(_on_avatar_loaded)
	friends_list.clear()
	for i in Steam.getFriendCount():
		var friend_id: int = Steam.getFriendByIndex(i, Steam.FRIEND_FLAG_IMMEDIATE)
		var game_info: Dictionary = Steam.getFriendGamePlayed(friend_id)
		if game_info.is_empty():
			continue
		if game_info["id"] != Steam.getAppID():
			continue
		if game_info["lobby"] != 0:
			continue
		Steam.getPlayerAvatar(Steam.AVATAR_LARGE, friend_id)

func _on_avatar_loaded(id: int, icon_size: int, bytes: PackedByteArray) -> void:
	var friend_name: String = Steam.getFriendPersonaName(id)
	var friend_icon: ImageTexture = Player.load_icon(icon_size, bytes)
	var i: int = friends_list.add_item(friend_name, friend_icon, false)
	friends_list.set_item_tooltip_enabled(i, false)
	friends.append(id)

func _on_friends_list_item_clicked(i: int, _pos: Vector2, button_index: int) -> void:
	if button_index != MOUSE_BUTTON_LEFT:
		return
	if Steam.inviteUserToLobby(Network.lobby_id, friends[i]):
		friends_list.set_item_disabled(i, true)
		friends_list.set_item_text(i, "%s | Invite Sent" % friends_list.get_item_text(i))

func _on_close_btn_pressed() -> void:
	close()
