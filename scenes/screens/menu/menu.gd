extends Control

@export var back_btn: Button
@export var player_name_edit: LineEdit
@export var landing_menu: Control
# Host Menu
@export var host_menu: Control
@export var lobby_name_edit: LineEdit
@export var lobby_type_btn: OptionButton
@export var max_players_lbl: Label
@export var max_players_slider: Slider
# Join Menu
@export var join_menu: Control
@export var lobby_search_edit: LineEdit
@export var lobbies_lbl: Label
@export var lobbies_container: VBoxContainer

func _ready() -> void:
	Steam.lobby_match_list.connect(_on_lobby_match_list)
	initialise_options()
	return_to_landing_menu()

func initialise_options() -> void:
	# Player name
	player_name_edit.set_text(GameState.player.name)
	# Lobby type
	for type: Steam.LobbyType in GameSettings.LOBBY_TYPES:
		lobby_type_btn.add_item(GameSettings.LOBBY_TYPES[type], type)
	lobby_type_btn.select(0)
	# Max players
	max_players_slider.min_value = GameSettings.MIN_PLAYERS
	max_players_slider.max_value = GameSettings.MAX_PLAYERS
	max_players_slider.value = GameSettings.MAX_PLAYERS
	max_players_lbl.set_text(str(GameSettings.MAX_PLAYERS))

func return_to_landing_menu() -> void:
	back_btn.hide()
	landing_menu.show()
	host_menu.hide()
	join_menu.hide()

func set_player_name() -> bool:
	if player_name_edit.text.is_empty():
		Feedback.display_error("Player name is required")
		return false
	GameState.player.name = player_name_edit.text
	return true

func _on_host_btn_pressed() -> void:
	back_btn.show()
	landing_menu.hide()
	host_menu.show()

func _on_max_players_slider_value_changed(value: float) -> void:
	max_players_lbl.set_text(str(int(value)))

func _on_host_lobby_btn_pressed() -> void:
	if not set_player_name():
		return
	var settings := GameSettings.new()
	settings.lobby_name = GameState.player.name if lobby_name_edit.text.is_empty() else lobby_name_edit.text
	settings.lobby_type = lobby_type_btn.get_selected_id() as Steam.LobbyType
	settings.max_players = int(max_players_slider.value)
	Network.create_lobby(settings)

func _on_join_btn_pressed() -> void:
	back_btn.show()
	landing_menu.hide()
	join_menu.show()
	refresh_lobbies()

func _on_lobby_search_edit_text_changed(_new_text: String) -> void:
	refresh_lobbies()

func refresh_lobbies() -> void:
	for child in lobbies_container.get_children():
		child.queue_free()
	lobbies_lbl.set_text("Searching for lobbies...")
	# TODO: Lobby list filters
	Steam.requestLobbyList()

func _on_lobby_match_list(lobbies: Array) -> void:
	for lobby_id: int in lobbies:
		#if Network.get_lobby_data_by_id(lobby_id, "app_name") != Global.app_name:
			#continue
		var lobby_name: String = Network.get_lobby_data_by_id(lobby_id, "name")
		if lobby_name.is_empty():
			continue
		var search: String = lobby_search_edit.text.to_lower()
		if not search.is_empty() and not lobby_name.to_lower().begins_with(search):
			continue
		var member_count: int = Steam.getNumLobbyMembers(lobby_id)
		var max_members: int = Steam.getLobbyMemberLimit(lobby_id)
		var join_lobby_btn := Button.new()
		join_lobby_btn.set_text("%s | %s/%s" % [lobby_name, member_count, max_members])
		join_lobby_btn.set_focus_mode(Control.FOCUS_NONE)
		join_lobby_btn.set_text_alignment(HORIZONTAL_ALIGNMENT_LEFT)
		join_lobby_btn.pressed.connect(_on_join_lobby_btn_pressed.bind(lobby_id))
		lobbies_container.add_child(join_lobby_btn)
	if lobbies_container.get_child_count() > 0:
		lobbies_lbl.set_text("")
	else:
		lobbies_lbl.set_text("No available lobbies :(")

func _on_join_lobby_btn_pressed(lobby_id: int) -> void:
	if not set_player_name():
		return
	Network.join_lobby(lobby_id)
