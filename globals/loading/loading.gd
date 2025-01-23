extends CanvasLayer

const MESSAGE_DISPLAY_TIME = 0.1

enum Scene { MENU, LOBBY }

const SCENE_PATHS: Dictionary = {
	Scene.MENU: "res://scenes/screens/menu/menu.tscn",
	Scene.LOBBY: "res://scenes/screens/lobby/lobby.tscn"
}

@export var message_lbl: Label
@export var progress_bar: ProgressBar
@export var anim_player: AnimationPlayer
@export var progress_timer: Timer

signal loading_complete

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
	if not progress_timer.is_stopped():
		Feedback.display_error("Error loading %s scene: Another scene is already loading" % Scene.find_key(scene), true)
		loading_complete.emit()
		return
	await start()
	ResourceLoader.load_threaded_request(SCENE_PATHS[scene])
	progress_timer.timeout.connect(_on_progress_timer_timeout.bind(scene))
	progress_timer.start()
	await loading_complete
	if finish_when_loaded:
		await finish()

func _on_progress_timer_timeout(scene: Scene) -> void:
	var path: String = SCENE_PATHS[scene]
	var progress: Array = []
	match ResourceLoader.load_threaded_get_status(path, progress):
		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE, ResourceLoader.THREAD_LOAD_FAILED:
			progress_timer.stop()
			progress_timer.timeout.disconnect(_on_progress_timer_timeout)
			Feedback.display_error("Error loading %s scene: Failed to load resource" % Scene.find_key(scene), true)
			loading_complete.emit()
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			progress_bar.visible = true
			progress_bar.value = progress[0] * 100
		ResourceLoader.THREAD_LOAD_LOADED:
			progress_timer.stop()
			progress_timer.timeout.disconnect(_on_progress_timer_timeout)
			var scene_node: Node = ResourceLoader.load_threaded_get(path).instantiate()
			get_tree().current_scene.queue_free()
			get_tree().root.add_child(scene_node)
			get_tree().set_current_scene(scene_node)
			await get_tree().process_frame
			loading_complete.emit()
