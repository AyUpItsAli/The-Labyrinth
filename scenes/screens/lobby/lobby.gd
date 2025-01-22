extends Control

@export var lobby_name_lbl: Label
@export var player_list: ItemList
@export var start_btn: Button
@export var chat_box: RichTextLabel
@export var message_edit: LineEdit

func _ready() -> void:
	Network.connection_successful.connect(_on_connection_successful)
	GameState.players_updated.connect(_on_players_updated)
	GameState.chat_updated.connect(_on_chat_updated)
	message_edit.grab_focus()

func _on_connection_successful() -> void:
	lobby_name_lbl.set_text("Lobby: %s" % Network.get_lobby_data("name", "???"))
	start_btn.set_disabled(not multiplayer.is_server())

func _on_players_updated() -> void:
	player_list.clear()
	for player: Player in GameState.get_players_sorted():
		player_list.add_item(player.name, player.icon)

func _on_chat_updated() -> void:
	pass

func _on_message_edit_text_submitted(message: String) -> void:
	message_edit.clear()
	GameState.send_chat_message(message)

func _on_leave_btn_pressed() -> void:
	Network.leave_server()
