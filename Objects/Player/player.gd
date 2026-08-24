extends CharacterBody2D


@export var SPEED = 100.0
@export var JUMP_VELOCITY = -300.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction: -1, 0, 16
	var direction := Input.get_axis("move_left", "move_right")
	
	# Determine Sprite orientation and animation
	if self.is_on_floor():
		if direction == 0.0:
			animated_sprite.play("idle")
		else:
			animated_sprite.play("run")

		
	# Determine Sprite Orientation
	if direction > 0:
		animated_sprite.flip_h = false
	elif direction < 0:
		animated_sprite.flip_h = true

	
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)


	move_and_slide()
