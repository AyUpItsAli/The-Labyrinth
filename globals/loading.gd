extends Node

enum Scene { MENU, LOBBY, LABYRINTH }

const SCENE_PATHS: Dictionary = {
	Scene.MENU: "res://scenes/screens/menu/menu.tscn",
	Scene.LOBBY: "res://scenes/screens/lobby/lobby.tscn",
	Scene.LABYRINTH: "res://scenes/world/labyrinth.tscn"
}

const PROGRESS_INTERVAL = 0.1

var progress_timer: Timer

signal loading_complete

func load_scene(scene: Scene) -> void:
	if progress_timer and not progress_timer.is_stopped():
		Overlay.display_error_popup("Error loading %s scene: Another scene is already loading" % Scene.find_key(scene), true)
		loading_complete.emit()
		return
	await Overlay.start_loading()
	ResourceLoader.load_threaded_request(SCENE_PATHS[scene])
	progress_timer = Timer.new()
	add_child(progress_timer)
	progress_timer.set_wait_time(PROGRESS_INTERVAL)
	progress_timer.timeout.connect(_on_progress_timer_timeout.bind(scene))
	progress_timer.start()

func _on_progress_timer_timeout(scene: Scene) -> void:
	var path: String = SCENE_PATHS[scene]
	var progress: Array = []
	match ResourceLoader.load_threaded_get_status(path, progress):
		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE, ResourceLoader.THREAD_LOAD_FAILED:
			progress_timer.queue_free()
			Overlay.display_error_popup("Error loading %s scene: Failed to load resource" % Scene.find_key(scene), true)
			loading_complete.emit()
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			Overlay.update_loading_progress(progress[0] * 100)
		ResourceLoader.THREAD_LOAD_LOADED:
			progress_timer.queue_free()
			var scene_node: Node = ResourceLoader.load_threaded_get(path).instantiate()
			get_tree().current_scene.queue_free()
			get_tree().root.add_child(scene_node)
			get_tree().set_current_scene(scene_node)
			await get_tree().process_frame
			loading_complete.emit()
