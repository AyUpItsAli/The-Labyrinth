class_name InvitePopup extends OverlayPopup

@export var friends_list: ItemList

var friends: Array

func _ready() -> void:
	super._ready()
	friends_list.clear()
	for f in Steam.getFriendCount():
		var friend_id: int = Steam.getFriendByIndex(f, Steam.FRIEND_FLAG_IMMEDIATE)
		var game_info: Dictionary = Steam.getFriendGamePlayed(friend_id)
		if game_info.is_empty():
			continue
		if game_info.get("id") != Steam.getAppID():
			continue
		if game_info.get("lobby") != 0:
			continue
		var friend_name: String = Steam.getFriendPersonaName(friend_id)
		var friend_icon: ImageTexture = await Player.get_icon(friend_id)
		var i: int = friends_list.add_item(friend_name, friend_icon, false)
		friends_list.set_item_tooltip_enabled(i, false)
		friends.append(friend_id)

func _on_friends_list_item_clicked(i: int, _pos: Vector2, button_index: int) -> void:
	if button_index != MOUSE_BUTTON_LEFT:
		return
	if Steam.inviteUserToLobby(Network.lobby_id, friends[i]):
		friends_list.set_item_disabled(i, true)
		friends_list.set_item_text(i, "%s | Invite Sent" % friends_list.get_item_text(i))

func _on_close_btn_pressed() -> void:
	close()
