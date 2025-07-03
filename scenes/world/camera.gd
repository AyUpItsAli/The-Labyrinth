class_name Camera extends Node3D

@export_group("Movement")
@export var move_speed: float = 0.35
@export var move_weight: float = 0.1
@export_group("Rotation")
@export var rotate_speed: float = 1
@export var rotate_weight: float = 0.1
@export var mouse_sensitivity: float = 0.16
@export var initial_pitch: float = -40
@export var min_pitch: float = -90
@export var max_pitch: float = 0
@export_group("Zoom")
@export var zoom_speed: float = 3
@export var zoom_weight: float = 0.1
@export var initial_zoom: float = 20
@export var min_zoom: float = 1
@export var max_zoom: float = 50
@export_group("Nodes")
@export var pitch_pivot: Node3D
@export var camera: Camera3D

@onready var move_target: Vector3 = position
@onready var rotate_target: float = rotation_degrees.y
@onready var zoom_target: float = initial_zoom

var max_distance: float

func _ready() -> void:
	pitch_pivot.rotation_degrees.x = initial_pitch

func _process(_delta: float) -> void:
	# Get input
	var move_input: Vector2 = Input.get_vector("left", "right", "forward", "back")
	var rotate_input: float = Input.get_axis("rotate_right", "rotate_left")
	var zoom_input := int(Input.is_action_just_released("zoom_out")) - int(Input.is_action_just_released("zoom_in"))
	# Calculate direction
	var direction := (transform.basis * Vector3(move_input.x, 0, move_input.y)).normalized()
	# Set targets
	move_target += direction * move_speed
	rotate_target += rotate_input * rotate_speed
	zoom_target += zoom_input * zoom_speed
	# Clamp/Wrap targets
	move_target.x = clampf(move_target.x, -max_distance, max_distance)
	move_target.z = clampf(move_target.z, -max_distance, max_distance)
	rotate_target = fposmod(rotate_target, 360)
	zoom_target = clamp(zoom_target, min_zoom, max_zoom)
	# Interpolate values
	position = lerp(position, move_target, move_weight)
	rotation.y = lerp_angle(rotation.y, deg_to_rad(rotate_target), rotate_weight)
	camera.position.z = lerp(camera.position.z, zoom_target, zoom_weight)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_action_pressed("rotate"):
		rotate_target -= event.relative.x * mouse_sensitivity
		pitch_pivot.rotation_degrees.x -= event.relative.y * mouse_sensitivity
		pitch_pivot.rotation_degrees.x = clamp(pitch_pivot.rotation_degrees.x, min_pitch, max_pitch)
	elif event.is_action_pressed("rotate"):
		Overlay.hide_cursor()
	elif event.is_action_released("rotate"):
		Overlay.show_cursor()

func get_mouse_pos() -> Vector3:
	var viewport_pos: Vector2 = get_viewport().get_mouse_position()
	var from: Vector3 = camera.project_ray_origin(viewport_pos)
	var to: Vector3 = camera.project_position(viewport_pos, 1000)
	var result: Variant = Plane.PLANE_XZ.intersects_segment(from, to)
	return Vector3.ZERO if result == null else result
