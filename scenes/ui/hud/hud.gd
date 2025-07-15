class_name HUD extends CanvasLayer

const PLAYER_PANEL = preload("res://scenes/ui/hud/player_panel.tscn")

@export_group("Player List")
@export var player_list: Container
@export_group("Chat")
@export var chat_btn: BaseButton
@export var chat: Container
@export_group("Player Panel")
@export var player_icon: TextureRect
@export var display_name_lbl: Label
@export_group("Actions")
@export var end_turn_btn: BaseButton

func _ready() -> void:
	GameState.phase_changed.connect(update_actions)

func update() -> void:
	update_player_list()
	update_chat()
	update_player_panel()
	update_actions()

# ------------
# PLAYER LIST
# ------------

func update_player_list() -> void:
	# Clear player list
	for child in player_list.get_children():
		player_list.remove_child(child)
		child.queue_free()
	# Get players in the correct order based on the current turn order
	var players: Array[Player]
	var prepend: bool
	for player: Player in GameState.turn_order:
		if player.id == Global.player.id:
			prepend = true
			continue
		if prepend:
			players.push_front(player)
		else:
			players.push_back(player)
	# Add player panels
	for player: Player in players:
		var panel: PlayerPanel = PLAYER_PANEL.instantiate()
		panel.icon.set_texture(player.icon)
		panel.name_lbl.set_text(player.display_name)
		player_list.add_child(panel)

# -----
# CHAT
# -----

func update_chat() -> void:
	chat.visible = chat_btn.button_pressed

func _on_chat_btn_pressed() -> void:
	update_chat()

# -------------
# PLAYER PANEL
# -------------

func update_player_panel() -> void:
	player_icon.set_texture(Global.player.icon)
	display_name_lbl.set_text(Global.player.display_name)

# --------
# ACTIONS
# --------

func update_actions() -> void:
	end_turn_btn.disabled = not (GameState.is_my_turn() and GameState.is_phase(GameState.TurnPhase.END))

func _on_end_turn_btn_pressed() -> void:
	GameState.next_turn.rpc()
