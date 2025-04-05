extends CanvasLayer

const LOADING_MESSAGE_DURATION = 0.1

const MESSAGE_POPUP = preload("res://globals/overlay/popups/message_popup.tscn")
const INVITE_POPUP = preload("res://globals/overlay/popups/invite_popup.tscn")

@export_group("Popups")
@export var popup_panel: Panel
@export var popup_container: Container
@export_group("Loading Screen")
@export var loading_screen: Control
@export var message_lbl: Label
@export var progress_bar: ProgressBar
@export var anim_player: AnimationPlayer
@export_group("Cursor")
@export var arrow_texture: Texture
@export var arrow_hotspot: Vector2
@export var ibeam_texture: Texture
@export var ibeam_hotspot: Vector2

func _ready() -> void:
	Input.set_custom_mouse_cursor(arrow_texture, Input.CURSOR_ARROW, arrow_hotspot)
	Input.set_custom_mouse_cursor(ibeam_texture, Input.CURSOR_IBEAM, ibeam_hotspot)
	update_popup_panel()

# -------
# POPUPS
# -------

func update_popup_panel() -> void:
	popup_panel.visible = popup_container.get_child_count() > 0

func display_popup(popup: OverlayPopup) -> void:
	popup_panel.show()
	popup.tree_exited.connect(update_popup_panel)
	popup_container.add_child(popup)

func display_message(message: String, text_color: Color = Color.WHITE) -> void:
	var popup: MessagePopup = MESSAGE_POPUP.instantiate()
	popup.message_lbl.set_text(message)
	popup.message_lbl.set_modulate(text_color)
	display_popup(popup)

func display_error(message: String, log_error: bool = false) -> void:
	if log_error:
		Logging.log_error(message)
	display_message(message, Color("ff5c5c"))

func display_invite_popup() -> void:
	display_popup(INVITE_POPUP.instantiate())

# ----------------
# LOADING SCREEN
# ----------------

func start_loading() -> void:
	if loading_screen.visible:
		return
	anim_player.play("fade_in")
	await anim_player.animation_finished

func finish_loading() -> void:
	if not loading_screen.visible:
		return
	message_lbl.set_text("")
	progress_bar.hide()
	anim_player.play("fade_out")
	await anim_player.animation_finished

func display_loading_message(message: String) -> void:
	await start_loading()
	message_lbl.set_text(message)
	await get_tree().create_timer(LOADING_MESSAGE_DURATION).timeout

func update_loading_progress(value: float) -> void:
	progress_bar.show()
	progress_bar.set_value(value)
