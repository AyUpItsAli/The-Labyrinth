extends CanvasLayer

const MESSAGE_DISPLAY_TIME = 0.1

enum Scene {
	MENU,
	LOBBY
}

const SCENE_PATHS: Dictionary = {
	Scene.MENU: "res://scenes/screens/menu/menu.tscn",
	Scene.LOBBY: "res://scenes/screens/lobby/lobby.tscn"
}

@export var message_lbl: Label
@export var progress_bar: ProgressBar
@export var anim_player: AnimationPlayer
@export var progress_timer: Timer

signal scene_loaded

func _ready() -> void:
	finish()

func start() -> void:
	if visible:
		return
	message_lbl.text = ""
	progress_bar.hide()
	anim_player.play("fade_in")
	await anim_player.animation_finished

func finish() -> void:
	if not visible:
		return
	message_lbl.text = ""
	progress_bar.hide()
	anim_player.play("fade_out")
	await anim_player.animation_finished

func display_message(message: String) -> void:
	await start()
	message_lbl.text = message
	await get_tree().create_timer(MESSAGE_DISPLAY_TIME).timeout

func load_scene(scene: Scene, finish_when_loaded: bool = true) -> void:
	await start()
	var scene_path: String = SCENE_PATHS[scene]
	ResourceLoader.load_threaded_request(scene_path)
	progress_timer.timeout.connect(_on_progress_timer_timeout.bind(scene_path))
	progress_timer.start()
	await scene_loaded
	if finish_when_loaded:
		await finish()

func _on_progress_timer_timeout(scene_path: String) -> void:
	var progress: Array = []
	match ResourceLoader.load_threaded_get_status(scene_path, progress):
		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE, ResourceLoader.THREAD_LOAD_FAILED:
			progress_timer.stop()
			progress_timer.timeout.disconnect(_on_progress_timer_timeout)
			Logging.log_error("Failed to load scene: %s" % scene_path)
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			progress_bar.visible = true
			progress_bar.value = progress[0] * 100
		ResourceLoader.THREAD_LOAD_LOADED:
			progress_timer.stop()
			progress_timer.timeout.disconnect(_on_progress_timer_timeout)
			var scene: Node = ResourceLoader.load_threaded_get(scene_path).instantiate()
			get_tree().current_scene.queue_free()
			get_tree().root.add_child(scene)
			get_tree().set_current_scene(scene)
			await get_tree().process_frame
			scene_loaded.emit()
