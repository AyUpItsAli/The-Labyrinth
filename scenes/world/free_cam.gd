class_name FreeCam extends Camera3D

@export var max_speed: float = 30
@export var acceleration: float = 50
@export var look_speed: float = 400

var velocity: Vector3
var angles: Vector2
var enabled: bool

func _ready() -> void:
	angles = Vector2(rotation.y, rotation.x)

func _physics_process(delta: float) -> void:
	if not enabled:
		return
	
	angles.y = clamp(angles.y, PI / -2.0, PI / 2.0)
	rotation = Vector3(angles.y, angles.x, 0)
	
	var direction_2d: Vector2 = Input.get_vector("left", "right", "forward", "back")
	var direction := Vector3(direction_2d.x, 0, direction_2d.y)
	if Input.is_action_pressed("up"):
		direction += Vector3.UP
	if Input.is_action_pressed("down"):
		direction += Vector3.DOWN
	
	velocity = velocity.move_toward(direction * max_speed, acceleration)
	translate(velocity * delta)

func _unhandled_input(event: InputEvent) -> void:
	if enabled and event is InputEventMouseMotion:
		angles -= event.relative / look_speed
	elif event.is_action_pressed("toggle_free_cam"):
		enabled = not enabled
