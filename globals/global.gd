extends Node

# Application
var app_name: String
var app_version: String

# Steam
var steam_initialised: bool
var is_subscribed: bool
var player := Player.new()

signal game_closed

func _init() -> void:
	app_name = ProjectSettings.get_setting("application/config/name")
	app_version = ProjectSettings.get_setting("application/config/version")

func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	initialise_steam()
	if steam_initialised:
		reset()

func initialise_steam() -> void:
	var response: Dictionary = Steam.get_steam_init_result()
	if not response or response.get("status") != 0:
		var reason: String = str(response.get("verbal")) if response else "No init response"
		Overlay.display_error("Error initialising Steam: %s" % reason, true)
		return
	steam_initialised = true
	is_subscribed = Steam.isSubscribed()
	if not is_subscribed:
		Overlay.display_error("Error initialising Steam: You do not own this application", true)

func reset() -> void:
	# Player
	player = Player.new()
	player.steam_id = Steam.getSteamID()
	player.steam_name = Steam.getPersonaName()
	player.display_name = player.steam_name
	player.load_icon()
	# Network and GameState
	Network.reset()
	GameState.reset()

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
