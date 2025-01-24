extends Node

const APP_ID = 480

var app_name: String
var app_version: String

var steam_active: bool
var is_owned: bool
var steam_id: int
var steam_username: String

signal game_closed

func _init() -> void:
	OS.set_environment("SteamAppId", str(APP_ID))
	OS.set_environment("SteamGameId", str(APP_ID))
	app_name = ProjectSettings.get_setting("application/config/name")
	app_version = ProjectSettings.get_setting("application/config/version")

func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	initialise_steam()

func _process(_delta: float) -> void:
	if steam_active:
		Steam.run_callbacks()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()

func quit_game() -> void:
	await Loading.start()
	game_closed.emit()
	get_tree().quit()

func initialise_steam() -> void:
	if steam_active:
		return
	
	var response: Dictionary = Steam.steamInit()
	if response["status"] != 1:
		Dialog.display_error("Failed to initialise Steamworks API: %s" % str(response["verbal"]), true)
		return
	
	steam_active = true
	is_owned = Steam.isSubscribed()
	
	if not is_owned:
		Dialog.display_error("Failed to initialise Steamworks API: You do not own this application", true)
		return
	
	steam_id = Steam.getSteamID()
	steam_username = Steam.getPersonaName()
