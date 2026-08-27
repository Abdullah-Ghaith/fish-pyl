extends CharacterBody2D

@export var projectile_scene: PackedScene = preload("res://Objects/Hook/hook.tscn")
@onready var trajectory_line: TrajectoryLine = $TrajectoryLine
@onready var fishing_line: FishingLine = $FishingLine

var projectile_speed: float = 0.0
var projectile_gravity: float = 0.0
var current_hook: Hook = null


func _ready() -> void:
	if projectile_scene:
		var temp_projectile: Hook = projectile_scene.instantiate()
		projectile_speed = temp_projectile.speed
		projectile_gravity = temp_projectile.gravity
		temp_projectile.free() # Clean up the temporary node from memory


func _physics_process(delta: float) -> void:
	if Input.is_action_pressed("ui_left"):
		rotation -= delta
	elif Input.is_action_pressed("ui_right"):
		rotation += delta
	if Input.is_action_pressed("ui_up"):
		projectile_speed += 200 * delta
	elif Input.is_action_pressed("ui_down"):
		projectile_speed -= 200 * delta
	projectile_speed = clamp(projectile_speed, 100.0, 2000.0)
	if Input.is_action_just_pressed("ui_accept"):
		shoot()
	trajectory_line.rotation = -rotation
	trajectory_line.update_trajectory(
		$ShootPos.global_transform.x,
		projectile_speed,
		projectile_gravity,
		delta
	)


func shoot() -> void:
	# One hook at a time, otherwise the line has two masters.
	reel_in()

	var instance: Hook = projectile_scene.instantiate()
	instance.dir = $ShootPos.global_transform.x
	instance.speed = projectile_speed
	get_parent().add_child(instance)
	instance.global_position = $ShootPos.global_position
	current_hook = instance

	# The line now runs rod tip -> hook and pays out as the hook flies.
	instance.entered_water.connect(fishing_line._on_hook_entered_water)
	fishing_line.attach_hook(instance)


func reel_in() -> void:
	fishing_line.detach_hook()
	if is_instance_valid(current_hook):
		current_hook.queue_free()
	current_hook = null
