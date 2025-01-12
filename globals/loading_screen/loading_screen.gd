extends CanvasLayer

const MESSAGE_DISPLAY_TIME = 0.5

@export var message_lbl: Label
@export var progress_bar: ProgressBar
@export var anim_player: AnimationPlayer

func _ready() -> void:
	if visible:
		end()

func begin() -> void:
	message_lbl.text = ""
	progress_bar.hide()
	anim_player.play("fade_in")
	await anim_player.animation_finished

func end() -> void:
	message_lbl.text = ""
	progress_bar.hide()
	anim_player.play("fade_out")
	await anim_player.animation_finished

func display_message(message: String) -> void:
	if not visible:
		await begin()
	message_lbl.text = message
	await get_tree().create_timer(MESSAGE_DISPLAY_TIME).timeout

func load_scene(scene_path: String) -> void:
	if not visible:
		await begin()
	get_tree().change_scene_to_file(scene_path)
	end()
