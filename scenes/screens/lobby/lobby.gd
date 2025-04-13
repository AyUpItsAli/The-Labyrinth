extends Control

const CHAT_MESSAGE = preload("res://scenes/ui/chat/chat_message.tscn")

@export var lobby_name_lbl: Label
@export var invite_btn: Button
@export var member_count_lbl: Label
@export var chat_container: ScrollContainer
@export var message_container: Container
@export var message_edit: LineEdit
@export var player_list: ItemList
@export var start_btn: Button

func _ready() -> void:
	GameState.chat_updated.connect(update_chat)
	GameState.players_updated.connect(update_players)
	lobby_name_lbl.set_text("Lobby: %s" % Network.get_lobby_data("name", "???"))
	invite_btn.set_visible(multiplayer.is_server())
	start_btn.set_visible(multiplayer.is_server())
	message_edit.grab_focus()
	update_chat()
	update_players()
	Overlay.finish_loading()

func _on_invite_btn_pressed() -> void:
	Overlay.display_invite_popup()

func update_chat() -> void:
	for child in message_container.get_children():
		message_container.remove_child(child)
		child.queue_free()
	for msg: Dictionary in GameState.chat:
		var message: ChatMessage = CHAT_MESSAGE.instantiate()
		match msg.get("type"):
			GameState.MessageType.SERVER:
				message.content_lbl.set_text("[center]%s[/center]" % msg.get("content"))
				message.timestamp_lbl.hide()
			_:
				message.content_lbl.set_text(msg.get("content"))
				var time: Dictionary = Time.get_time_dict_from_unix_time(msg.get("time"))
				message.timestamp_lbl.set_text("%02d:%02d" % [time.get("hour"), time.get("minute")])
		message_container.add_child(message)
	# No idea why we need to wait 2 frames, instead of 1, before setting scroll
	await get_tree().process_frame
	await get_tree().process_frame
	# Scroll to end
	chat_container.set_v_scroll(Vector2i.MAX.x)

func _on_message_edit_text_submitted(content: String) -> void:
	message_edit.clear()
	GameState.send_player_message(content)

func update_players() -> void:
	# Update lobby title with new player count
	var member_count: int = GameState.players.size()
	var max_members: int = Steam.getLobbyMemberLimit(Network.lobby_id)
	member_count_lbl.set_text("%s/%s" % [member_count, max_members])
	# Update player list
	player_list.clear()
	for player: Player in GameState.get_players_sorted():
		var i: int = player_list.add_item(player.name, player.icon, false)
		player_list.set_item_tooltip_enabled(i, false)

func _on_leave_btn_pressed() -> void:
	Network.leave_server()

func _on_start_btn_pressed() -> void:
	start_game.rpc()

@rpc("authority", "call_local", "reliable")
func start_game() -> void:
	Loading.load_scene(Loading.Scene.LABYRINTH)
