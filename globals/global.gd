extends Node

var app_name: String
var app_version: String

var steam_initialised: bool
var is_owned: bool
var steam_id: int
var steam_username: String

signal game_closed

func _init() -> void:
	app_name = ProjectSettings.get_setting("application/config/name")
	app_version = ProjectSettings.get_setting("application/config/version")

func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	initialise_steam()

func initialise_steam() -> void:
	var response: Dictionary = Steam.get_steam_init_result()
	if not response or response.get("status") != 0:
		var reason: String = str(response.get("verbal")) if response else "No init response"
		Overlay.display_error("Failed to initialise Steam: %s" % reason, true)
		return
	
	steam_initialised = true
	is_owned = Steam.isSubscribed()
	
	if not is_owned:
		Overlay.display_error("Failed to initialise Steam: You do not own this application", true)
		return
	
	steam_id = Steam.getSteamID()
	steam_username = Steam.getPersonaName()

func _process(_delta: float) -> void:
	if steam_initialised:
		Steam.run_callbacks()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()

func quit_game() -> void:
	await Overlay.start_loading()
	game_closed.emit()
	get_tree().quit()
