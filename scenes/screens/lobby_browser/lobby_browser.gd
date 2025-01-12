extends Control

@export var player_name_edit: LineEdit
@export var lobby_search_edit: LineEdit
@export var lobbies_lbl: Label
@export var lobbies_container: VBoxContainer

func _ready() -> void:
	Steam.lobby_match_list.connect(_on_lobby_match_list)
	Network.connection_successful.connect(_on_connection_successful)
	Network.connection_closed.connect(_on_connection_closed)
	player_name_edit.set_text(GameState.player.name)
	refresh_lobbies()

func _on_quit_btn_pressed() -> void:
	Global.quit_game()

func _on_lobbies_back_btn_pressed() -> void:
	LoadingScreen.load_scene("res://scenes/screens/menu/menu.tscn")

func _on_lobby_search_edit_text_changed(_new_text: String) -> void:
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
		if Network.get_lobby_data_by_id(lobby_id, "app_name") != Global.app_name:
			continue
		var lobby_name: String = Network.get_lobby_data_by_id(lobby_id, "name")
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
	LoadingScreen.load_scene("res://scenes/screens/lobby/lobby.tscn")

func _on_connection_closed() -> void:
	LoadingScreen.load_scene("res://scenes/screens/menu/menu.tscn")
