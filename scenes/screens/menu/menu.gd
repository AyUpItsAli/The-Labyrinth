extends Control

const LOBBY_LIST_ITEM = preload("res://scenes/screens/menu/lobby_list_item.tscn")

@export var back_btn: Button
@export var display_name_edit: LineEdit
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
@export var friends_filter_btn: CheckBox
@export var searching_lbl: Label
@export var lobby_list: VBoxContainer

func _ready() -> void:
	Steam.lobby_match_list.connect(_on_lobby_match_list)
	initialise_options()
	return_to_landing_menu()
	Overlay.finish_loading()

func initialise_options() -> void:
	# Display name
	display_name_edit.set_text(GameState.player.name)
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
	if display_name_edit.text.is_empty():
		Overlay.display_error("Display name is required")
		return false
	GameState.player.name = display_name_edit.text
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

func _on_friends_filter_btn_toggled(_toggled_on: bool) -> void:
	refresh_lobbies()

func refresh_lobbies() -> void:
	for child in lobby_list.get_children():
		child.queue_free()
	searching_lbl.set_text("Searching for lobbies...")
	Steam.requestLobbyList()

func _on_lobby_match_list(lobbies: Array) -> void:
	if friends_filter_btn.button_pressed:
		await request_friend_lobbies()
	else:
		for lobby_id: int in lobbies:
			add_lobby(lobby_id)
	if lobby_list.get_child_count() > 0:
		searching_lbl.set_text("")
	else:
		searching_lbl.set_text("No available lobbies :(")

func request_friend_lobbies() -> void:
	for i in Steam.getFriendCount():
		var friend_id: int = Steam.getFriendByIndex(i, Steam.FRIEND_FLAG_IMMEDIATE)
		var game_info: Dictionary = Steam.getFriendGamePlayed(friend_id)
		if game_info.is_empty():
			continue
		if game_info["id"] != Steam.getAppID():
			continue
		var lobby_id: int = game_info["lobby"]
		if lobby_id == 0:
			continue
		Steam.requestLobbyData(lobby_id)
		await Steam.lobby_data_update
		add_lobby(lobby_id)

func add_lobby(lobby_id: int) -> void:
	if Network.get_lobby_data_by_id(lobby_id, "app_name") != Global.app_name:
		return
	var lobby_name: String = Network.get_lobby_data_by_id(lobby_id, "name")
	if lobby_name.is_empty():
		return
	var search: String = lobby_search_edit.text.to_lower()
	if not search.is_empty() and not lobby_name.to_lower().begins_with(search):
		return
	var member_count: int = Steam.getNumLobbyMembers(lobby_id)
	var max_members: int = Steam.getLobbyMemberLimit(lobby_id)
	var item: LobbyListItem = LOBBY_LIST_ITEM.instantiate()
	item.name_lbl.set_text(lobby_name)
	item.member_count_lbl.set_text("%s/%s" % [member_count, max_members])
	item.join_btn.pressed.connect(_on_join_lobby_btn_pressed.bind(lobby_id))
	lobby_list.add_child(item)

func _on_join_lobby_btn_pressed(lobby_id: int) -> void:
	if not set_player_name():
		return
	Network.join_lobby(lobby_id)
