extends Control

@export var player_name_edit: LineEdit

@export var host_or_join: Control
@export var lobby_name_edit: LineEdit

@export var lobby_browser: Control
@export var lobby_search_edit: LineEdit
@export var lobbies_lbl: Label
@export var lobbies_container: VBoxContainer

@export var lobby: Control
@export var lobby_name_lbl: Label
@export var player_list: ItemList
@export var start_btn: Button
@export var chat_box: RichTextLabel
@export var message_edit: LineEdit

func _ready() -> void:
	Steam.lobby_match_list.connect(_on_lobby_match_list)
	Network.connection_successful.connect(_on_connection_successful)
	Network.connection_closed.connect(_on_connection_closed)
	GameState.players_changed.connect(_on_players_changed)
	
	player_name_edit.set_text(GameState.player.name)
	switch_to_host_or_join()

func _on_quit_btn_pressed() -> void:
	Global.quit_game()

func switch_to_host_or_join() -> void:
	player_name_edit.show()
	host_or_join.show()
	lobby_browser.hide()
	lobby.hide()

func switch_to_lobby_browser() -> void:
	player_name_edit.show()
	host_or_join.hide()
	lobby_browser.show()
	lobby.hide()
	refresh_lobbies()

func switch_to_lobby() -> void:
	player_name_edit.hide()
	host_or_join.hide()
	lobby_browser.hide()
	lobby_name_lbl.set_text("Lobby: %s" % Network.get_lobby_data("name", "???"))
	start_btn.set_disabled(not multiplayer.is_server())
	lobby.show()

func _on_host_btn_pressed() -> void:
	if player_name_edit.text.is_empty():
		Logging.log_error("Player name must not be empty")
		return
	GameState.player.name = player_name_edit.text
	Network.create_lobby(GameState.player.name if lobby_name_edit.text.is_empty() else lobby_name_edit.text)

func _on_join_btn_pressed() -> void:
	switch_to_lobby_browser()

func _on_lobbies_back_btn_pressed() -> void:
	switch_to_host_or_join()

func _on_lobby_search_text_changed(_new_text: String) -> void:
	refresh_lobbies()

func _on_refresh_btn_pressed() -> void:
	refresh_lobbies()

func refresh_lobbies() -> void:
	for child in lobbies_container.get_children():
		child.queue_free()
	lobbies_lbl.set_text("Searching for lobbies...")
	# TODO: Lobby list filters
	Steam.requestLobbyList()

func _on_lobby_match_list(lobbies: Array) -> void:
	for lobby_id: int in lobbies:
		if Steam.getLobbyData(lobby_id, "game_name") != Global.GAME_NAME:
			continue
		var lobby_name: String = Steam.getLobbyData(lobby_id, "name")
		if lobby_name.is_empty():
			continue
		var search: String = lobby_search_edit.text.to_lower()
		if not search.is_empty() and not lobby_name.to_lower().begins_with(search):
			continue
		var member_count: int = Steam.getNumLobbyMembers(lobby_id)
		var max_members: int = Steam.getLobbyMemberLimit(lobby_id)
		var lobby_btn := Button.new()
		lobby_btn.set_text("%s | %s/%s" % [lobby_name, member_count, max_members])
		lobby_btn.set_focus_mode(FOCUS_NONE)
		lobby_btn.pressed.connect(_on_lobby_btn_pressed.bind(lobby_id))
		lobbies_container.add_child(lobby_btn)
	if lobbies_container.get_child_count() > 0:
		lobbies_lbl.set_text("")
	else:
		lobbies_lbl.set_text("No available lobbies :(")

func _on_lobby_btn_pressed(lobby_id: int) -> void:
	if player_name_edit.text.is_empty():
		Logging.log_error("Player name must not be empty")
		return
	GameState.player.name = player_name_edit.text
	Network.join_lobby(lobby_id)

func _on_connection_successful() -> void:
	switch_to_lobby()

func _on_players_changed() -> void:
	player_list.clear()
	for player: Player in GameState.get_players():
		player_list.add_item(player.name, player.icon)

func _on_message_edit_text_submitted(message: String) -> void:
	if message.is_empty():
		return
	message_edit.clear()
	send_chat_message.rpc_id(1, message)

@rpc("any_peer", "call_local", "reliable")
func send_chat_message(message: String) -> void:
	if not multiplayer.is_server():
		return
	var id: int = multiplayer.get_remote_sender_id()
	var player: Player = GameState.get_player(id)
	chat_box.text += "%s: %s\n" % [player.name, message]
	update_chat.rpc(chat_box.text)

@rpc("authority", "call_remote", "reliable")
func update_chat(text: String) -> void:
	chat_box.text = text

func _on_leave_btn_pressed() -> void:
	Network.leave_server()

func _on_connection_closed() -> void:
	switch_to_host_or_join()
