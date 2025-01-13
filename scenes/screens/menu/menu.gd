extends Control

@export var player_name_edit: LineEdit
@export var lobby_name_edit: LineEdit

func _ready() -> void:
	player_name_edit.set_text(GameState.player.name)

# TODO: Make Menu and Lobby Browser one scene

func _on_host_btn_pressed() -> void:
	if player_name_edit.text.is_empty():
		Logging.log_error("Player name must not be empty")
		return
	GameState.player.name = player_name_edit.text
	Network.create_lobby(GameState.player.name if lobby_name_edit.text.is_empty() else lobby_name_edit.text)

func _on_join_btn_pressed() -> void:
	Loading.load_scene(Loading.Scene.LOBBY_BROWSER)

func _on_quit_btn_pressed() -> void:
	Global.quit_game()
