extends Control

@export var lobby_name_lbl: Label
@export var invite_btn: Button
@export var member_count_lbl: Label
@export var message_edit: LineEdit
@export var player_list: ItemList
@export var start_btn: Button

func _ready() -> void:
	Network.players_updated.connect(update_players)
	lobby_name_lbl.set_text(Network.get_lobby_data("name", "Untitled Lobby"))
	invite_btn.set_visible(multiplayer.is_server())
	message_edit.grab_focus()
	update_players()
	Overlay.finish_loading()

func update_players() -> void:
	# Update lobby title with new player count
	var member_count: int = Network.players.size()
	var max_members: int = Steam.getLobbyMemberLimit(Network.lobby_id)
	member_count_lbl.set_text("%s/%s" % [member_count, max_members])
	# Update player list
	player_list.clear()
	for player: Player in Network.get_players_sorted():
		var i: int = player_list.add_item(player.display_name, player.icon, false)
		player_list.set_item_disabled(i, not player.ready)
		player_list.set_item_tooltip_enabled(i, false)
	# Update start button
	if multiplayer.is_server():
		start_btn.set_disabled(not Network.players_ready())
	else:
		start_btn.set_text("Unready" if Global.player.ready else "Ready")

func _on_invite_btn_pressed() -> void:
	Overlay.display_invite_popup()

func _on_start_btn_pressed() -> void:
	if multiplayer.is_server():
		load_game.rpc()
	else:
		Network.set_player_ready.rpc(Global.player.id, not Global.player.ready)

@rpc("authority", "call_local", "reliable")
func load_game() -> void:
	start_btn.set_disabled(true)
	Utils.log_start("Loading game")
	Loading.load_scene(Loading.Scene.LABYRINTH)

func _on_leave_btn_pressed() -> void:
	Network.leave_server()
