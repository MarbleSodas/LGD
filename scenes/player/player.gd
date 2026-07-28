extends CharacterBody2D

## Player movement speeds
@export var walk_speed: float = 160.0
@export var run_speed: float = 220.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var movement_enabled: bool = true

func _ready() -> void:
	sprite.play("idle")


func _physics_process(_delta: float) -> void:
	if not movement_enabled or (DialogueManager and DialogueManager.is_active()):
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Get input direction (8-directional)
	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_axis("Left", "Right")
	input_dir.y = Input.get_axis("Up", "Down")
	
	# Normalize for consistent diagonal speed
	var direction := input_dir.normalized()
	
	# Determine speed (shift to run)
	var speed := run_speed if Input.is_action_pressed("sprint") else walk_speed
	
	# Apply velocity
	velocity = direction * speed
	
	# Flip sprite based on horizontal direction
	if direction.x != 0:
		sprite.flip_h = direction.x > 0
	
	move_and_slide()

func get_interact_area() -> Area2D:
	return $InteractArea

func lock_movement() -> void:
	movement_enabled = false
	velocity = Vector2.ZERO

func unlock_movement() -> void:
	movement_enabled = true
