class_name Player extends CharacterBody2D

@export var SPEED = 100.0

@onready var animated_sprite: AnimatedSprite2D = %AnimatedSprite2D
@onready var state_machine: StateMachine = %StateMachine

var can_right: bool = true
var can_left: bool = true
var can_fire: bool = false

var last_catch: Array[FishData] = []

func move(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Input direction: -1, 0, 1
	var direction := Input.get_axis("move_left", "move_right")
	if not can_right and direction > 0.0:
		direction = 0.0
	if not can_left and direction < 0.0:
		direction = 0.0

	if is_on_floor():
		animated_sprite.play("idle" if direction == 0.0 else "run")

	if direction > 0.0:
		animated_sprite.flip_h = false
	elif direction < 0.0:
		animated_sprite.flip_h = true

	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)

	move_and_slide()

func enter_aiming_fishing_rod_state() -> void:
	state_machine.force_change_state("AimingFishingRodState")

func enter_fishing_state() -> void:
	state_machine.force_change_state("FishingState")

func enter_walking_state() -> void:
	state_machine.force_change_state("WalkingState")

func _on_fishing_rod_hook_fired() -> void:
	enter_fishing_state()
