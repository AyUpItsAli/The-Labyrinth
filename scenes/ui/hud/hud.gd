extends CanvasLayer

@export_group("Chat")
@export var chat_btn: BaseButton
@export var chat: Container
@export_group("Actions")
@export var end_turn_btn: BaseButton

func _ready() -> void:
	GameState.phase_changed.connect(update_actions)
	update_chat()
	update_actions()

# -----
# CHAT
# -----

func update_chat() -> void:
	chat.visible = chat_btn.button_pressed

func _on_chat_btn_pressed() -> void:
	update_chat()

# --------
# ACTIONS
# --------

func update_actions() -> void:
	end_turn_btn.disabled = not GameState.is_phase(GameState.TurnPhase.END)

func _on_end_turn_btn_pressed() -> void:
	GameState.next_turn.rpc()
